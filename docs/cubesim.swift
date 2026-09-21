// cubesim.swift — headless regression harness for the slice-rotation primitives.
//
//   swiftc -O -o cubesim cubesim.swift && ./cubesim
//
// Replicates rotateRow / rotateColumn / rotateLayer from ContentView.swift exactly:
// reparent the slice under a pivot, rotate the pivot, bake worldTransform, reparent to
// root, update the logical position, rename the node, snap to the clean lattice.
//
// The load-bearing assertion is BAKED vs CLAIMED:
//   baked   = translation the rotation actually produced (geometry)
//   claimed = lattice point the updated node name implies (bookkeeping)
// If those two disagree, the permutation is inverted relative to its own animation —
// which is precisely the rotateRow bug documented in docs/RESEARCH.md. Everything else
// in the app (hit testing, slice selection) reads the name, so the two must agree.

import Foundation
import SceneKit

let OFFSET: CGFloat = 0.34

final class Sim {
    let root = SCNNode()
    var mismatches: [String] = []
    var checks = 0

    init() {
        for x in 0..<3 { for y in 0..<3 { for z in 0..<3 {
            let n = SCNNode()
            n.name = "cube_\(x)_\(y)_\(z)"
            n.position = SCNVector3(CGFloat(x - 1) * OFFSET,
                                    CGFloat(y - 1) * OFFSET,
                                    CGFloat(z - 1) * OFFSET)
            root.addChildNode(n)
        }}}
    }

    func parse(_ n: SCNNode) -> (Int, Int, Int) {
        let p = n.name!.replacingOccurrences(of: "cube_", with: "").split(separator: "_")
        return (Int(p[0])!, Int(p[1])!, Int(p[2])!)
    }

    /// axis: 0 = X (rotateColumn), 1 = Y (rotateRow), 2 = Z (rotateLayer)
    func rotate(axis: Int, slice: Int, clockwise: Bool, label: String) {
        let pieces = root.childNodes.filter { n in
            let p = parse(n)
            return (axis == 0 ? p.0 : axis == 1 ? p.1 : p.2) == slice
        }
        precondition(pieces.count == 9, "\(label): found \(pieces.count) pieces, expected 9")

        // SCNAction angles exactly as ContentView.swift uses them.
        let angle: CGFloat
        switch axis {
        case 0:  angle = clockwise ?  .pi/2 : -(.pi/2)   // rotateColumn, +X
        case 1:  angle = clockwise ? -(.pi/2) :  .pi/2   // rotateRow,    +Y  (inverted sign)
        default: angle = clockwise ?  .pi/2 : -(.pi/2)   // rotateLayer,  +Z
        }

        let pivot = SCNNode()
        root.addChildNode(pivot)
        for n in pieces {
            let w = n.worldPosition
            n.removeFromParentNode()
            pivot.addChildNode(n)
            n.position = pivot.convertPosition(w, from: root)
        }
        switch axis {
        case 0:  pivot.eulerAngles = SCNVector3(angle, 0, 0)
        case 1:  pivot.eulerAngles = SCNVector3(0, angle, 0)
        default: pivot.eulerAngles = SCNVector3(0, 0, angle)
        }

        for n in pieces {
            let baked = n.worldTransform                 // what the rotation actually did
            n.removeFromParentNode()
            root.addChildNode(n)
            n.transform = baked

            let (x, y, z) = parse(n)
            let np: (Int, Int, Int)
            switch axis {
            case 0:  np = clockwise ? (x, 2 - z, y) : (x, z, 2 - y)
            case 1:  np = clockwise ? (2 - z, y, x) : (z, y, 2 - x)   // PATCHED branch order
            default: np = clockwise ? (2 - y, x, z) : (y, 2 - x, z)
            }
            n.name = "cube_\(np.0)_\(np.1)_\(np.2)"

            let claimed = SCNVector3(CGFloat(np.0 - 1) * OFFSET,
                                     CGFloat(np.1 - 1) * OFFSET,
                                     CGFloat(np.2 - 1) * OFFSET)
            checks += 1
            let d = max(abs(baked.m41 - claimed.x), max(abs(baked.m42 - claimed.y), abs(baked.m43 - claimed.z)))
            if d > 1e-4 {
                mismatches.append("\(label): (\(x),\(y),\(z)) baked (\(f(baked.m41)),\(f(baked.m42)),\(f(baked.m43))) vs claimed (\(f(claimed.x)),\(f(claimed.y)),\(f(claimed.z)))")
            }
            n.position = claimed
        }
        pivot.removeFromParentNode()
    }

    func f(_ v: CGFloat) -> String { String(format: "%+.2f", Double(v)) }

    /// Every node must sit on a distinct lattice point with an axis-aligned orientation.
    func invariants() -> [String] {
        var errs: [String] = []
        var slots = Set<String>(), names = Set<String>()
        for n in root.childNodes {
            names.insert(n.name!)
            let p = n.position
            for c in [p.x, p.y, p.z] {
                let nearest = [-OFFSET, 0, OFFSET].min(by: { abs($0 - c) < abs($1 - c) })!
                if abs(nearest - c) > 1e-4 { errs.append("\(n.name!) off-lattice at \(f(c))") }
            }
            slots.insert("\(f(p.x)),\(f(p.y)),\(f(p.z))")
            // rotation must be a signed permutation matrix
            let t = n.transform
            let cols = [[t.m11,t.m12,t.m13],[t.m21,t.m22,t.m23],[t.m31,t.m32,t.m33]]
            for col in cols {
                let mags = col.map { abs($0) }.sorted()
                if abs(mags[2] - 1) > 1e-4 || mags[1] > 1e-4 {
                    errs.append("\(n.name!) orientation not axis-aligned")
                }
            }
        }
        if slots.count != 27 { errs.append("only \(slots.count) distinct slots occupied (expected 27)") }
        if names.count != 27 { errs.append("only \(names.count) distinct names (expected 27)") }
        return errs
    }
}

// ---- run ----
let sim = Sim()
var rng = SystemRandomNumberGenerator()
let axisName = ["Column(X)", "Row(Y)", "Layer(Z)"]
let N = 500
for i in 0..<N {
    let a = Int.random(in: 0...2, using: &rng)
    let s = Int.random(in: 0...2, using: &rng)
    let cw = Bool.random(using: &rng)
    sim.rotate(axis: a, slice: s, clockwise: cw, label: "#\(i) \(axisName[a]) slice \(s) cw=\(cw)")
}

print("random moves applied      : \(N)")
print("baked-vs-claimed checks   : \(sim.checks)")
print("baked-vs-claimed mismatch : \(sim.mismatches.count)")
for m in sim.mismatches.prefix(6) { print("    \(m)") }

let errs = sim.invariants()
print("invariant violations      : \(errs.count)")
for e in errs.prefix(6) { print("    \(e)") }

let ok = sim.mismatches.isEmpty && errs.isEmpty
print("\nRESULT: \(ok ? "PASS — geometry and name bookkeeping agree on every move" : "FAIL")")
exit(ok ? 0 : 1)
