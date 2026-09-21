// lbl_dev.swift — development harness for the cubie state model + LBL solver.
//   swiftc -O -o lbl_dev lbl_dev.swift && ./lbl_dev
// Once green this splits into cubeGame/CubeState.swift + cubeGame/LBLSolver.swift.
//
// Design:
//   F2L (bottom cross, bottom corners, middle edges) — allocation-free IDA* per piece,
//     which keeps each sub-goal shallow and the moves short.
//   Last layer — exact BFS over the ~62k LL states using named beginner algorithms as
//     generators. Complete by construction, and every step is a teachable algorithm.

import Foundation

// MARK: - Cubie model (Kociemba conventions)
// Corners: URF UFL ULB UBR DFR DLF DBL DRB      (0...7)
// Edges:   UR UF UL UB DR DF DL DB FR FL BL BR  (0...11)

enum Corner: Int { case URF, UFL, ULB, UBR, DFR, DLF, DBL, DRB }
enum Edge: Int { case UR, UF, UL, UB, DR, DF, DL, DB, FR, FL, BL, BR }

enum Face: Int, CaseIterable { case U, D, L, R, F, B
    var name: String { ["U","D","L","R","F","B"][rawValue] }
    var opposite: Face { [Face.D,.U,.R,.L,.B,.F][rawValue] }
}

struct Move: Equatable, Hashable {
    let face: Face, turns: Int              // 1 cw, 2 half, 3 ccw
    init(_ f: Face, _ t: Int) { face = f; turns = ((t % 4) + 4) % 4 }
    var inverse: Move { Move(face, 4 - turns) }
    var notation: String { face.name + (turns == 1 ? "" : turns == 2 ? "2" : "'") }
    static func seq(_ m: [Move]) -> String { m.map(\.notation).joined(separator: " ") }
    static func invert(_ m: [Move]) -> [Move] { m.reversed().map(\.inverse) }
}

func parse(_ s: String) -> [Move] {
    s.split(separator: " ").map { tok in
        let f: Face = ["U": Face.U, "D": .D, "L": .L, "R": .R, "F": .F, "B": .B][String(tok.prefix(1))]!
        let sfx = tok.dropFirst()
        return Move(f, sfx == "'" ? 3 : sfx == "2" ? 2 : 1)
    }
}

struct BaseMove {
    let cp: [Int], co: [Int], ep: [Int], eo: [Int]
    static let z8 = [Int](repeating: 0, count: 8), z12 = [Int](repeating: 0, count: 12)
    static let table: [BaseMove] = [   // index == Face.rawValue: U D L R F B
        BaseMove(cp: [3,0,1,2,4,5,6,7], co: z8, ep: [3,0,1,2,4,5,6,7,8,9,10,11], eo: z12),
        BaseMove(cp: [0,1,2,3,5,6,7,4], co: z8, ep: [0,1,2,3,5,6,7,4,8,9,10,11], eo: z12),
        BaseMove(cp: [0,2,6,3,4,1,5,7], co: [0,1,2,0,0,2,1,0], ep: [0,1,10,3,4,5,9,7,8,2,6,11], eo: z12),
        BaseMove(cp: [4,1,2,0,7,5,6,3], co: [2,0,0,1,1,0,0,2], ep: [8,1,2,3,11,5,6,7,4,9,10,0], eo: z12),
        BaseMove(cp: [1,5,2,3,0,4,6,7], co: [1,2,0,0,2,1,0,0], ep: [0,9,2,3,4,8,6,7,1,5,10,11], eo: [0,1,0,0,0,1,0,0,1,1,0,0]),
        BaseMove(cp: [0,1,3,7,4,5,2,6], co: [0,0,1,2,0,0,2,1], ep: [0,1,2,11,4,5,6,10,8,9,3,7], eo: [0,0,0,1,0,0,0,1,0,0,1,1]),
    ]
    /// Pre-expanded to 18 moves so the hot loop never repeats a quarter turn.
    static let all18: [(move: Move, m: BaseMove)] = {
        var out: [(Move, BaseMove)] = []
        for f in Face.allCases { for t in 1...3 {
            var s = CubeState.solved
            for _ in 0..<t { s = s.applying(table[f.rawValue]) }
            out.append((Move(f, t), BaseMove(cp: s.cp, co: s.co, ep: s.ep, eo: s.eo)))
        }}
        return out
    }()
}

struct CubeState: Equatable {
    var cp = Array(0..<8), co = [Int](repeating: 0, count: 8)
    var ep = Array(0..<12), eo = [Int](repeating: 0, count: 12)
    static let solved = CubeState()
    var isSolved: Bool { self == CubeState.solved }

    // (A*B)(x).c = A(B(x).c).c ; (A*B)(x).o = A(B(x).c).o + B(x).o
    func applying(_ m: BaseMove) -> CubeState {
        var r = CubeState()
        for i in 0..<8  { r.cp[i] = cp[m.cp[i]]; r.co[i] = (co[m.cp[i]] + m.co[i]) % 3 }
        for i in 0..<12 { r.ep[i] = ep[m.ep[i]]; r.eo[i] = (eo[m.ep[i]] + m.eo[i]) % 2 }
        return r
    }
    func applying(_ mv: Move) -> CubeState {
        var s = self
        for _ in 0..<mv.turns { s = s.applying(BaseMove.table[mv.face.rawValue]) }
        return s
    }
    func applying(_ seq: [Move]) -> CubeState { seq.reduce(self) { $0.applying($1) } }

    var isValid: Bool {
        guard Set(cp) == Set(0..<8), Set(ep) == Set(0..<12) else { return false }
        guard co.allSatisfy({ (0...2).contains($0) }), eo.allSatisfy({ (0...1).contains($0) }) else { return false }
        guard co.reduce(0,+) % 3 == 0, eo.reduce(0,+) % 2 == 0 else { return false }
        return par(cp) == par(ep)
    }
    private func par(_ p: [Int]) -> Int {
        var n = 0; for i in 0..<p.count { for j in (i+1)..<p.count where p[i] > p[j] { n += 1 } }
        return n % 2
    }
}

// MARK: - Colours (this app's scheme: +X red −X orange +Y white −Y yellow +Z blue −Z green)

let faceColour: [Face: String] = [.U:"white", .D:"yellow", .L:"orange", .R:"red", .F:"blue", .B:"green"]
let cornerFaces: [[Face]] = [[.U,.R,.F],[.U,.F,.L],[.U,.L,.B],[.U,.B,.R],[.D,.F,.R],[.D,.L,.F],[.D,.B,.L],[.D,.R,.B]]
let edgeFaces:   [[Face]] = [[.U,.R],[.U,.F],[.U,.L],[.U,.B],[.D,.R],[.D,.F],[.D,.L],[.D,.B],[.F,.R],[.F,.L],[.B,.L],[.B,.R]]
func cornerName(_ i: Int) -> String { cornerFaces[i].map { faceColour[$0]! }.joined(separator: "-") }
func edgeName(_ i: Int) -> String { edgeFaces[i].map { faceColour[$0]! }.joined(separator: "-") }
func cornerSlot(_ i: Int) -> String { cornerFaces[i].map(\.name).joined() }
func edgeSlot(_ i: Int) -> String { edgeFaces[i].map(\.name).joined() }

// MARK: - Stages

enum Stage: Int {
    case bottomCross, bottomCorners, middleEdges, lastLayer, solved
    var title: String {
        ["Bottom cross","Bottom corners","Middle layer edges","Last layer","Solved"][rawValue]
    }
}

struct SolutionStep {
    let stage: Stage, cue: String, moves: [Move], corners: [Int], edges: [Int]
}

let D_EDGES   = [Edge.DR,.DF,.DL,.DB].map(\.rawValue)
let D_CORNERS = [Corner.DFR,.DLF,.DBL,.DRB].map(\.rawValue)
let E_EDGES   = [Edge.FR,.FL,.BL,.BR].map(\.rawValue)
let U_EDGES   = [Edge.UR,.UF,.UL,.UB].map(\.rawValue)
let U_CORNERS = [Corner.URF,.UFL,.ULB,.UBR].map(\.rawValue)

func edgePlaced(_ s: CubeState, _ i: Int) -> Bool { s.ep[i] == i && s.eo[i] == 0 }
func cornerPlaced(_ s: CubeState, _ i: Int) -> Bool { s.cp[i] == i && s.co[i] == 0 }
func f2lDone(_ s: CubeState) -> Bool {
    D_EDGES.allSatisfy { edgePlaced(s,$0) } && D_CORNERS.allSatisfy { cornerPlaced(s,$0) }
        && E_EDGES.allSatisfy { edgePlaced(s,$0) }
}
func stageOf(_ s: CubeState) -> Stage {
    if s.isSolved { return .solved }
    if !D_EDGES.allSatisfy({ edgePlaced(s,$0) }) { return .bottomCross }
    if !D_CORNERS.allSatisfy({ cornerPlaced(s,$0) }) { return .bottomCorners }
    if !E_EDGES.allSatisfy({ edgePlaced(s,$0) }) { return .middleEdges }
    return .lastLayer
}

// MARK: - Allocation-free IDA* over a flat state buffer
// layout per state: [0..<8] cp, [8..<16] co, [16..<28] ep, [28..<40] eo

struct Goal { var edges: [Int] = [], corners: [Int] = [] }   // must be placed (pos + ori)

final class Searcher {
    static let W = 40
    private var buf: [Int8]
    private var path: [Move] = []
    private let maxD: Int
    var nodes = 0

    init(maxDepth: Int) { maxD = maxDepth; buf = [Int8](repeating: 0, count: Searcher.W * (maxDepth + 2)) }

    private func load(_ s: CubeState) {
        for i in 0..<8  { buf[i] = Int8(s.cp[i]); buf[8+i] = Int8(s.co[i]) }
        for i in 0..<12 { buf[16+i] = Int8(s.ep[i]); buf[28+i] = Int8(s.eo[i]) }
    }
    private func apply(_ o1: Int, _ o2: Int, _ m: BaseMove) {
        for i in 0..<8 {
            let c = m.cp[i]
            buf[o2+i] = buf[o1+c]
            buf[o2+8+i] = (buf[o1+8+c] + Int8(m.co[i])) % 3
        }
        for i in 0..<12 {
            let e = m.ep[i]
            buf[o2+16+i] = buf[o1+16+e]
            buf[o2+28+i] = (buf[o1+28+e] + Int8(m.eo[i])) % 2
        }
    }
    private func hit(_ o: Int, _ g: Goal) -> Bool {
        for e in g.edges where buf[o+16+e] != Int8(e) || buf[o+28+e] != 0 { return false }
        for c in g.corners where buf[o+c] != Int8(c) || buf[o+8+c] != 0 { return false }
        return true
    }

    func search(_ start: CubeState, _ g: Goal) -> [Move]? {
        load(start)
        if hit(0, g) { return [] }
        for d in 1...maxD {
            path.removeAll(keepingCapacity: true)
            if dfs(0, d, nil, g) { return path }
        }
        return nil
    }
    private func dfs(_ off: Int, _ depth: Int, _ last: Face?, _ g: Goal) -> Bool {
        let n = off + Searcher.W
        for (mv, bm) in BaseMove.all18 {
            if let l = last {
                if mv.face == l { continue }
                // commuting pair: fix one order so each is explored once
                if mv.face == l.opposite && mv.face.rawValue > l.rawValue { continue }
            }
            nodes += 1
            apply(off, n, bm)
            path.append(mv)
            if depth == 1 {
                if hit(n, g) { return true }
            } else if dfs(n, depth - 1, mv.face, g) {
                return true
            }
            path.removeLast()
        }
        return false
    }
}

// MARK: - Last layer: exact BFS over LL states with named algorithms

struct LLAlg { let name: String, moves: [Move] }

/// LL state = (cp,co of URF UFL ULB UBR) + (ep,eo of UR UF UL UB), packed.
@inline(__always) func llIndex(_ s: CubeState) -> Int {
    var cpi = 0, epi = 0
    for i in 0..<4 { cpi = cpi * 4 + s.cp[i]; epi = epi * 4 + s.ep[i] }
    let coi = s.co[0] + 3 * s.co[1] + 9 * s.co[2]
    let eoi = s.eo[0] + 2 * s.eo[1] + 4 * s.eo[2]
    return ((cpi * 256 + epi) * 27 + coi) * 8 + eoi
}
let LL_SPACE = 256 * 256 * 27 * 8

enum LastLayer {
    static let algs: [LLAlg] = [
        LLAlg(name: "U",              moves: parse("U")),
        LLAlg(name: "U'",             moves: parse("U'")),
        LLAlg(name: "U2",             moves: parse("U2")),
        LLAlg(name: "edge flip (F R U R' U' F')", moves: parse("F R U R' U' F'")),
        LLAlg(name: "Sune (R U R' U R U2 R')",    moves: parse("R U R' U R U2 R'")),
        LLAlg(name: "Anti-Sune (R U2 R' U' R U' R')", moves: parse("R U2 R' U' R U' R'")),
        LLAlg(name: "edge cycle (R U R' U R U2 R' U)", moves: parse("R U R' U R U2 R' U")),
        LLAlg(name: "corner cycle (U R U' L' U R' U' L)", moves: parse("U R U' L' U R' U' L")),
        LLAlg(name: "T-perm (R U R' U' R' F R2 U' R' U' R U R' F')",
              moves: parse("R U R' U' R' F R2 U' R' U' R U R' F'")),
    ]
    /// generator set closed under inverse, so a BFS tree from solved yields paths both ways
    static let gens: [LLAlg] = {
        var g = algs
        for a in algs {
            let inv = Move.invert(a.moves)
            if !g.contains(where: { $0.moves == inv }) { g.append(LLAlg(name: a.name + " (reversed)", moves: inv)) }
        }
        return g
    }()

    /// parent[state] = (previousState, generatorIndex) on the path back to solved
    static var parent: [Int32] = []
    static var viaGen: [Int8] = []
    static var reached = 0

    static func build() {
        parent = [Int32](repeating: -1, count: LL_SPACE)
        viaGen = [Int8](repeating: -1, count: LL_SPACE)
        let root = llIndex(.solved)
        parent[root] = Int32(root)
        var frontier = [CubeState.solved]
        reached = 1
        while !frontier.isEmpty {
            var next: [CubeState] = []
            for st in frontier {
                let si = llIndex(st)
                for (gi, g) in gens.enumerated() {
                    let ns = st.applying(g.moves)
                    let ni = llIndex(ns)
                    if parent[ni] == -1 {
                        parent[ni] = Int32(si); viaGen[ni] = Int8(gi)
                        reached += 1
                        next.append(ns)
                    }
                }
            }
            frontier = next
        }
    }

    /// Steps taking `s` (F2L complete) to solved.
    static func solveSteps(_ s: CubeState) -> [SolutionStep]? {
        var idx = llIndex(s)
        guard parent[idx] != -1 else { return nil }
        // walk back to root collecting generators, then invert the walk
        var chain: [Int] = []
        while parent[idx] != Int32(idx) {
            chain.append(Int(viaGen[idx]))
            idx = Int(parent[idx])
        }
        var out: [SolutionStep] = []
        var cur = s
        for gi in chain {                       // solved --g--> state, so apply g⁻¹ to undo
            let g = gens[gi]
            let mv = Move.invert(g.moves)
            let before = cur
            cur = cur.applying(mv)
            out.append(SolutionStep(stage: .lastLayer,
                                    cue: llCue(before, mv),
                                    moves: mv, corners: U_CORNERS, edges: U_EDGES))
        }
        return cur.isSolved ? out : nil
    }

    static func llCue(_ s: CubeState, _ mv: [Move]) -> String {
        let n = Move.seq(mv)
        if mv.allSatisfy({ $0.face == .U }) { return "Turn the top face to line the last layer up — \(n)." }
        if !U_EDGES.allSatisfy({ s.eo[$0] == 0 }) { return "Orient the top edges into a \(faceColour[.U]!) cross — \(n)." }
        if !U_EDGES.allSatisfy({ s.ep[$0] == $0 }) { return "Cycle the top edges into place — \(n)." }
        if !U_CORNERS.allSatisfy({ s.cp[$0] == $0 }) { return "Cycle the top corners into place — \(n)." }
        return "Twist the top corners \(faceColour[.U]!)-side up — \(n)."
    }
}

// MARK: - Solver

enum Solver {
    static let f2lDepth = 7
    static var fallbacks = 0, maxDepthUsed = 0

    static func nextStep(_ s: CubeState) -> SolutionStep? {
        switch stageOf(s) {
        case .solved: return nil
        case .lastLayer: return LastLayer.solveSteps(s)?.first
        case .bottomCross:
            let done = D_EDGES.filter { edgePlaced(s,$0) }
            guard let t = D_EDGES.first(where: { !edgePlaced(s,$0) }) else { return nil }
            guard let mv = Searcher(maxDepth: f2lDepth).search(s, Goal(edges: done + [t])) else { return nil }
            maxDepthUsed = max(maxDepthUsed, mv.count)
            return SolutionStep(stage: .bottomCross,
                                cue: "Put the \(edgeName(t)) edge into \(edgeSlot(t)) — \(Move.seq(mv)).",
                                moves: mv, corners: [], edges: [t])
        case .bottomCorners:
            let done = D_CORNERS.filter { cornerPlaced(s,$0) }
            guard let t = D_CORNERS.first(where: { !cornerPlaced(s,$0) }) else { return nil }
            guard let mv = Searcher(maxDepth: f2lDepth)
                .search(s, Goal(edges: D_EDGES, corners: done + [t])) else { return nil }
            maxDepthUsed = max(maxDepthUsed, mv.count)
            return SolutionStep(stage: .bottomCorners,
                                cue: "Seat the \(cornerName(t)) corner into \(cornerSlot(t)) — \(Move.seq(mv)).",
                                moves: mv, corners: [t], edges: [])
        case .middleEdges:
            let done = E_EDGES.filter { edgePlaced(s,$0) }
            guard let t = E_EDGES.first(where: { !edgePlaced(s,$0) }) else { return nil }
            guard let mv = Searcher(maxDepth: f2lDepth)
                .search(s, Goal(edges: D_EDGES + done + [t], corners: D_CORNERS)) else { return nil }
            maxDepthUsed = max(maxDepthUsed, mv.count)
            return SolutionStep(stage: .middleEdges,
                                cue: "Insert the \(edgeName(t)) edge into \(edgeSlot(t)) — \(Move.seq(mv)).",
                                moves: mv, corners: [], edges: [t])
        }
    }

    static func solve(_ start: CubeState, cap: Int = 60) -> [SolutionStep]? {
        var s = start, out: [SolutionStep] = []
        while !s.isSolved {
            if out.count > cap { return nil }
            if f2lDone(s) {
                guard let ll = LastLayer.solveSteps(s) else { return nil }
                out += ll
                s = s.applying(ll.flatMap(\.moves))
                break
            }
            guard let step = nextStep(s) else { return nil }
            s = s.applying(step.moves)
            out.append(step)
        }
        return s.isSolved ? out : nil
    }
}

// MARK: - Tests

var fails = 0
func check(_ c: Bool, _ label: String) { if !c { fails += 1; print("  FAIL: \(label)") } }

print("=== move tables ===")
for f in Face.allCases {
    var s = CubeState.solved
    for _ in 0..<4 { s = s.applying(Move(f,1)) }
    check(s.isSolved, "\(f.name)^4 == identity")
    check(CubeState.solved.applying(Move(f,1)).applying(Move(f,3)).isSolved, "\(f.name) \(f.name)'")
    check(!CubeState.solved.applying(Move(f,1)).isSolved, "\(f.name) changes the cube")
    check(CubeState.solved.applying(Move(f,1)).isValid, "\(f.name) legal")
}
var sx = CubeState.solved
for _ in 0..<6 { sx = sx.applying(parse("R U R' U'")) }
check(sx.isSolved, "(R U R' U')^6 == identity")
check(CubeState.solved.applying(parse("R U R' U' R' F R2 U' R' U' R U R' F'")).isValid, "T-perm legal")
var t2 = CubeState.solved.applying(parse("R U R' U' R' F R2 U' R' U' R U R' F'"))
t2 = t2.applying(parse("R U R' U' R' F R2 U' R' U' R U R' F'"))
check(t2.isSolved, "T-perm is an involution")
print("  \(fails == 0 ? "OK" : "\(fails) failures")")

print("\n=== last-layer BFS ===")
let tb = Date()
LastLayer.build()
print("  generators : \(LastLayer.gens.count)")
print("  LL states reached : \(LastLayer.reached)")
print("  build time : \(String(format: "%.2f", Date().timeIntervalSince(tb)))s")

print("\n=== validity under random play ===")
var g = SystemRandomNumberGenerator()
func scramble(_ n: Int) -> [Move] {
    var out: [Move] = []; var last: Face? = nil
    while out.count < n {
        let f = Face.allCases.randomElement(using: &g)!
        if f == last { continue }
        last = f; out.append(Move(f, Int.random(in: 1...3, using: &g)))
    }
    return out
}
var vfail = 0
for _ in 0..<3000 where !CubeState.solved.applying(scramble(25)).isValid { vfail += 1 }
check(vfail == 0, "3000 random states all legal")
print("  \(vfail == 0 ? "OK" : "\(vfail) invalid")")

print("\n=== solver ===")
var solved = 0, failed = 0, lens: [Int] = [], steps: [Int] = []
let N = 200
let t0 = Date()
for i in 0..<N {
    let sc = scramble(25)
    let start = CubeState.solved.applying(sc)
    guard let sol = Solver.solve(start) else {
        failed += 1; if failed <= 3 { print("  UNSOLVED #\(i): \(Move.seq(sc))") }; continue
    }
    let all = sol.flatMap(\.moves)
    if start.applying(all).isSolved { solved += 1; lens.append(all.count); steps.append(sol.count) }
    else { failed += 1; if failed <= 3 { print("  WRONG #\(i): \(Move.seq(sc))") } }
}
let dt = Date().timeIntervalSince(t0)
print("  solved   : \(solved)/\(N)")
print("  failed   : \(failed)")
if !lens.isEmpty {
    print("  moves avg/min/max : \(lens.reduce(0,+)/lens.count) / \(lens.min()!) / \(lens.max()!)")
    print("  hints avg/max     : \(steps.reduce(0,+)/steps.count) / \(steps.max()!)")
    print("  deepest F2L search: \(Solver.maxDepthUsed)")
}
print("  time     : \(String(format: "%.1f", dt))s  (\(String(format: "%.1f", Double(N)/dt))/s)")

print("\n=== worked example ===")
let demo = CubeState.solved.applying(parse("R U R' U' F2 L D B' R2 U"))
if let sol = Solver.solve(demo) {
    for st in sol.prefix(6) { print("  [\(st.stage.title)] \(st.cue)") }
    print("  ... \(sol.count) hints, \(sol.flatMap(\.moves).count) moves total")
}

let ok = fails == 0 && failed == 0 && LastLayer.reached > 0
print("\nRESULT: \(ok ? "PASS" : "FAIL")")
exit(ok ? 0 : 1)
