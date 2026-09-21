import Foundation
import SceneKit

// Replicate the app: a piece at logical (0,0,0) -> world (-0.34, -0.34, -0.34)
// reparented under a rotation node, rotated by the SCNAction angle used in rotateRow.
func test(axis: String, angle: CGFloat) -> SCNVector3 {
    let root = SCNNode()
    let parent = SCNNode()
    root.addChildNode(parent)
    let piece = SCNNode()
    piece.position = SCNVector3(-0.34, -0.34, -0.34)
    parent.addChildNode(piece)
    switch axis {
    case "y": parent.eulerAngles = SCNVector3(0, angle, 0)
    case "x": parent.eulerAngles = SCNVector3(angle, 0, 0)
    default:  parent.eulerAngles = SCNVector3(0, 0, angle)
    }
    return piece.worldPosition
}
func logical(_ v: SCNVector3) -> String {
    func q(_ f: CGFloat) -> Int { Int((f/0.34).rounded()) + 1 }
    return "(\(q(v.x)), \(q(v.y)), \(q(v.z)))"
}
print("start logical (0,0,0)")
print("rotateRow clockwise=true   SCNAction y:-pi/2  -> visual lands at \(logical(test(axis:"y", angle: -.pi/2)))   code says (0,0,2)")
print("rotateRow clockwise=false  SCNAction y:+pi/2  -> visual lands at \(logical(test(axis:"y", angle:  .pi/2)))   code says (2,0,0)")
print("rotateCol clockwise=true   SCNAction x:+pi/2  -> visual lands at \(logical(test(axis:"x", angle:  .pi/2)))   code says (0,2,0)")
print("rotateLay clockwise=true   SCNAction z:+pi/2  -> visual lands at \(logical(test(axis:"z", angle:  .pi/2)))   code says (2,0,0)")
