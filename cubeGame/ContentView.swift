//
//  ContentView.swift
//  cubeGame
//
//  Created by Kushal on 30/09/25.
//

import SwiftUI
import SceneKit
import Combine

// MARK: - Cube Piece Model
class CubePiece {
    var position: (x: Int, y: Int, z: Int)
    var colors: [Color] // 6 colors for 6 faces: [right, left, top, bottom, front, back]
    var node: SCNNode
    
    init(position: (x: Int, y: Int, z: Int), colors: [Color], node: SCNNode) {
        self.position = position
        self.colors = colors
        self.node = node
    }
}

// MARK: - Rubik's Cube Model
class RubiksCube: ObservableObject {
    var pieces: [CubePiece] = []
    
    let faceColors: [Color] = [.blue, .green, .red, .yellow, .orange, .pink]
    
    init() {
        resetCube()
    }
    
    func resetCube() {
        pieces = []
    }
    
    func scramble() {
        // Scramble by performing random rotations
        let moves: [String] = ["R", "L", "U", "D", "F", "B"]
        for _ in 0..<10 {
            _ = moves.randomElement()
        }
    }
}

// MARK: - Interactive 3D Rubik's Cube View
struct Interactive3DCubeView: UIViewRepresentable {
    @ObservedObject var cube: RubiksCube
    
    func makeUIView(context: Context) -> SCNView {
        let sceneView = SCNView()
        let scene = createScene(context: context)
        sceneView.scene = scene
        sceneView.allowsCameraControl = false
        sceneView.backgroundColor = UIColor.white
        sceneView.autoenablesDefaultLighting = false
        
        context.coordinator.sceneView = sceneView
        
        // Add pan gesture for one-finger interactions (swipe for slice rotation, drag for cube rotation)
        let panGesture = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        panGesture.minimumNumberOfTouches = 1
        panGesture.maximumNumberOfTouches = 1
        sceneView.addGestureRecognizer(panGesture)
        
        return sceneView
    }
    
    func updateUIView(_ uiView: SCNView, context: Context) {
        // No need to recreate scene
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(cube: cube)
    }
    
    class Coordinator: NSObject {
        var cube: RubiksCube
        weak var sceneView: SCNView?
        var gestureStartLocation: CGPoint?
        var cumulativeTranslation: CGPoint = CGPoint.zero
        var isSwipeGesture = false
        var currentCameraAngle: (x: Float, y: Float) = (0.3, 0.3)
        var isAnimating = false
        
        init(cube: RubiksCube) {
            self.cube = cube
        }
        
        func getCubePiecesInRow(_ row: Int) -> [CubePiece] {
            var pieces: [CubePiece] = []
            guard let scene = sceneView?.scene else { return pieces }
            
            for x in 0..<3 {
                for z in 0..<3 {
                    let nodeName = "cube_\(x)_\(row)_\(z)"
                    if let node = scene.rootNode.childNode(withName: nodeName, recursively: true) {
                        let colors: [Color] = [
                            cube.faceColors[1], cube.faceColors[3], cube.faceColors[4],
                            cube.faceColors[2], cube.faceColors[0], cube.faceColors[5]
                        ]
                        let piece = CubePiece(position: (x, row, z), colors: colors, node: node)
                        pieces.append(piece)
                    }
                }
            }
            return pieces
        }
        
        func getCubePiecesInColumn(_ column: Int) -> [CubePiece] {
            var pieces: [CubePiece] = []
            guard let scene = sceneView?.scene else { return pieces }
            
            for y in 0..<3 {
                for z in 0..<3 {
                    let nodeName = "cube_\(column)_\(y)_\(z)"
                    if let node = scene.rootNode.childNode(withName: nodeName, recursively: true) {
                        let colors: [Color] = [
                            cube.faceColors[1], cube.faceColors[3], cube.faceColors[4],
                            cube.faceColors[2], cube.faceColors[0], cube.faceColors[5]
                        ]
                        let piece = CubePiece(position: (column, y, z), colors: colors, node: node)
                        pieces.append(piece)
                    }
                }
            }
            return pieces
        }
        
        func getCubePiecesInLayer(_ layer: Int) -> [CubePiece] {
            var pieces: [CubePiece] = []
            guard let scene = sceneView?.scene else { return pieces }
            
            for x in 0..<3 {
                for y in 0..<3 {
                    let nodeName = "cube_\(x)_\(y)_\(layer)"
                    if let node = scene.rootNode.childNode(withName: nodeName, recursively: true) {
                        let colors: [Color] = [
                            cube.faceColors[1], cube.faceColors[3], cube.faceColors[4],
                            cube.faceColors[2], cube.faceColors[0], cube.faceColors[5]
                        ]
                        let piece = CubePiece(position: (x, y, layer), colors: colors, node: node)
                        pieces.append(piece)
                    }
                }
            }
            return pieces
        }
        
        
        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let sceneView = sceneView else { return }
            
            let location = gesture.location(in: sceneView)
            let touchCount = gesture.numberOfTouches
            
            switch gesture.state {
            case .began:
                if touchCount == 1 {
                    gestureStartLocation = location
                    cumulativeTranslation = CGPoint.zero
                    isSwipeGesture = false
                }
                
            case .changed:
                if touchCount == 1 {
                    let translation = gesture.translation(in: sceneView)
                    let velocity = gesture.velocity(in: sceneView)
                    
                    // Detect gesture type based on movement pattern
                    let distance = sqrt(cumulativeTranslation.x * cumulativeTranslation.x + 
                                     cumulativeTranslation.y * cumulativeTranslation.y)
                    let velocityMagnitude = sqrt(velocity.x * velocity.x + velocity.y * velocity.y)
                    
                    // Updated thresholds for better distinction
                    let minDistanceForDrag: CGFloat = 20  // Minimum distance before drag starts
                    let swipeVelocityThreshold: CGFloat = 500  // Higher velocity for swipe
                    let swipeDistanceThreshold: CGFloat = 15   // Shorter distance for swipe
                    
                    // Only process gesture if minimum movement threshold is met
                    if distance > minDistanceForDrag && !isSwipeGesture {
                        // Check if this is a quick swipe
                        if velocityMagnitude > swipeVelocityThreshold && distance > swipeDistanceThreshold {
                            // This is a swipe - perform cube slice rotation
                            isSwipeGesture = true
                            performCubeSliceRotation(
                                translation: translation,
                                startLocation: gestureStartLocation!,
                                in: sceneView
                            )
                        } else {
                            // This is a drag - rotate entire cube
                            rotateEntireCube(gesture: gesture, in: sceneView)
                        }
                    }
                    
                    // Update cumulative translation
                    cumulativeTranslation.x += translation.x
                    cumulativeTranslation.y += translation.y
                }
                
            case .ended, .cancelled:
                gestureStartLocation = nil
                cumulativeTranslation = CGPoint.zero
                isSwipeGesture = false
                
            default:
                break
            }
        }
        
        func rotateEntireCube(gesture: UIPanGestureRecognizer, in view: UIView) {
            // Rotate the entire cube by rotating camera around it
            let translation = gesture.translation(in: view)
            
            currentCameraAngle.y += Float(translation.x) * 0.01
            currentCameraAngle.x -= Float(translation.y) * 0.01
            
            currentCameraAngle.x = max(-Float.pi/2, min(Float.pi/2, currentCameraAngle.x))
            
            if let cameraNode = sceneView?.scene?.rootNode.childNode(withName: "camera", recursively: true) {
                let distance: Float = 4.0
                let x = distance * cos(currentCameraAngle.x) * sin(currentCameraAngle.y)
                let y = distance * sin(currentCameraAngle.x)
                let z = distance * cos(currentCameraAngle.x) * cos(currentCameraAngle.y)
                
                cameraNode.position = SCNVector3(x, y, z)
                cameraNode.look(at: SCNVector3(0, 0, 0))
            }
            
            gesture.setTranslation(.zero, in: view)
        }
        
        func performCubeSliceRotation(translation: CGPoint, startLocation: CGPoint, in sceneView: SCNView) {
            guard !isAnimating else { return }
            
            // Find hit piece at start location
            guard let hitPiece = findHitCubePiece(at: startLocation, in: sceneView) else {
                print("❌ No cube piece found at swipe location")
                return
            }
            
            // Determine rotation based on swipe direction
            let swipeVector = CGPoint(x: translation.x, y: translation.y)
            
            // Convert to world space swipe direction
            guard let cameraNode = sceneView.scene?.rootNode.childNode(withName: "camera", recursively: true) else {
                print("❌ Camera node not found")
                return
            }
            
            let cameraDirection = SCNVector3(-cameraNode.position.x, -cameraNode.position.y, -cameraNode.position.z)
            let normalizedCameraDirection = normalize(cameraDirection)
            
            // Convert swipe to world space
            let worldSwipeDirection = convertSwipeToWorldSpace(swipeVector: swipeVector, cameraNode: cameraNode)
            
            // Determine rotation axis and slice
            let rotationInfo = determineRotationAxisAndSlice(
                swipeDirection: worldSwipeDirection,
                cameraDirection: normalizedCameraDirection,
                hitPiece: hitPiece
            )
            
            // Perform the rotation
            performArbitraryAxisRotation(
                axis: rotationInfo.axis,
                sliceIndex: rotationInfo.sliceIndex,
                clockwise: rotationInfo.clockwise
            )
        }
        
        // MARK: - Camera-Relative Rotation System
        
        
        func findHitCubePiece(at point: CGPoint, in sceneView: SCNView) -> CubePiece? {
            // Try hit testing to find the node
            let options: [SCNHitTestOption: Any] = [
                .searchMode: SCNHitTestSearchMode.all.rawValue,
                .ignoreHiddenNodes: false,
                .ignoreChildNodes: false,
                .backFaceCulling: false,
                .boundingBoxOnly: false,
                .firstFoundOnly: true
            ]
            
            let hitResults = sceneView.hitTest(point, options: options)
            
            if let firstHit = hitResults.first {
                // Extract position from node name
                if let nodeName = firstHit.node.name, nodeName.hasPrefix("cube_") {
                    let components = nodeName.replacingOccurrences(of: "cube_", with: "").split(separator: "_")
                    if components.count == 3,
                       let x = Int(components[0]),
                       let y = Int(components[1]),
                       let z = Int(components[2]) {
                        
                        // Create colors array
                        let colors: [Color] = [
                            cube.faceColors[1], // Right face - Green
                            cube.faceColors[3], // Left face - Yellow  
                            cube.faceColors[4], // Top face - Orange
                            cube.faceColors[2], // Bottom face - Red
                            cube.faceColors[0], // Front face - Blue
                            cube.faceColors[5]  // Back face - Pink
                        ]
                        
                        let piece = CubePiece(position: (x, y, z), colors: colors, node: firstHit.node)
                        print("   🎯 Hit cube piece at logical position: (\(x), \(y), \(z))")
                        return piece
                    }
                }
            }
            
            print("   ❌ No cube piece found at touch location")
            return nil
        }
        
        
        func convertSwipeToWorldSpace(swipeVector: CGPoint, cameraNode: SCNNode) -> SCNVector3 {
            // Get camera's right and up vectors
            let cameraTransform = cameraNode.transform
            let rightVector = SCNVector3(cameraTransform.m11, cameraTransform.m12, cameraTransform.m13)
            let upVector = SCNVector3(cameraTransform.m21, cameraTransform.m22, cameraTransform.m23)
            
            // Convert screen swipe to world space
            let worldSwipe = SCNVector3(
                Float(swipeVector.x) * rightVector.x + Float(swipeVector.y) * upVector.x,
                Float(swipeVector.x) * rightVector.y + Float(swipeVector.y) * upVector.y,
                Float(swipeVector.x) * rightVector.z + Float(swipeVector.y) * upVector.z
            )
            
            return normalize(worldSwipe)
        }
        
        struct RotationInfo {
            let axis: SCNVector3
            let sliceIndex: Int
            let clockwise: Bool
        }
        
        func determineRotationAxisAndSlice(swipeDirection: SCNVector3, cameraDirection: SCNVector3, hitPiece: CubePiece) -> RotationInfo {
            // For a more intuitive camera-relative rotation, we should determine the rotation axis
            // based on which face of the cube was touched and the swipe direction
            
            // First, let's try a simpler approach: determine the rotation based on the swipe direction
            // and the camera's current orientation
            
            let (x, y, z) = hitPiece.position
            
            // Convert swipe direction to a more intuitive rotation axis
            // The idea is: if user swipes right, rotate the slice that makes sense from camera view
            
            // Determine which axis the swipe is most aligned with in screen space
            let absSwipeX = abs(swipeDirection.x)
            let absSwipeY = abs(swipeDirection.y)
            let absSwipeZ = abs(swipeDirection.z)
            
            print("   🎯 Swipe direction analysis: X=\(swipeDirection.x), Y=\(swipeDirection.y), Z=\(swipeDirection.z)")
            
            let rotationAxis: SCNVector3
            let sliceIndex: Int
            let clockwise: Bool
            
            if absSwipeX > absSwipeY && absSwipeX > absSwipeZ {
                // Swipe is primarily in X direction - rotate around X axis
                rotationAxis = SCNVector3(1, 0, 0)
                sliceIndex = x
                clockwise = swipeDirection.x > 0
                print("   🔄 X-axis rotation based on swipe direction")
            } else if absSwipeY > absSwipeX && absSwipeY > absSwipeZ {
                // Swipe is primarily in Y direction - rotate around Y axis
                rotationAxis = SCNVector3(0, 1, 0)
                sliceIndex = y
                clockwise = swipeDirection.y > 0
                print("   🔄 Y-axis rotation based on swipe direction")
            } else {
                // Swipe is primarily in Z direction - rotate around Z axis
                rotationAxis = SCNVector3(0, 0, 1)
                sliceIndex = z
                clockwise = swipeDirection.z > 0
                print("   🔄 Z-axis rotation based on swipe direction")
            }
            
            print("   🧮 Rotation axis: \(rotationAxis)")
            print("   📍 Slice index: \(sliceIndex)")
            print("   🎯 Direction: \(clockwise ? "CLOCKWISE" : "COUNTER-CLOCKWISE")")
            
            return RotationInfo(axis: rotationAxis, sliceIndex: sliceIndex, clockwise: clockwise)
        }
        
        func determineSliceAndDirection(axis: SCNVector3, hitPiece: CubePiece) -> (sliceIndex: Int, clockwise: Bool) {
            let (x, y, z) = hitPiece.position
            
            // Determine which axis is most dominant
            let absX = abs(axis.x)
            let absY = abs(axis.y)
            let absZ = abs(axis.z)
            
            print("   🧮 Axis components: X=\(axis.x), Y=\(axis.y), Z=\(axis.z)")
            print("   🧮 Absolute values: X=\(absX), Y=\(absY), Z=\(absZ)")
            
            // The key insight: we need to determine which slice to rotate based on
            // the rotation axis and the hit piece. The slice should be perpendicular to the rotation axis.
            
            if absX > absY && absX > absZ {
                // Rotation around X-axis - we want to rotate a slice perpendicular to X-axis
                // This means we rotate pieces with the same X coordinate (a Y-Z plane slice)
                let clockwise = axis.x > 0
                print("   🔄 X-axis rotation, rotating X-slice: \(x), clockwise: \(clockwise)")
                return (x, clockwise)
            } else if absY > absX && absY > absZ {
                // Rotation around Y-axis - we want to rotate a slice perpendicular to Y-axis
                // This means we rotate pieces with the same Y coordinate (an X-Z plane slice)
                let clockwise = axis.y > 0
                print("   🔄 Y-axis rotation, rotating Y-slice: \(y), clockwise: \(clockwise)")
                return (y, clockwise)
            } else {
                // Rotation around Z-axis - we want to rotate a slice perpendicular to Z-axis
                // This means we rotate pieces with the same Z coordinate (an X-Y plane slice)
                let clockwise = axis.z > 0
                print("   🔄 Z-axis rotation, rotating Z-slice: \(z), clockwise: \(clockwise)")
                return (z, clockwise)
            }
        }
        
        func performArbitraryAxisRotation(axis: SCNVector3, sliceIndex: Int, clockwise: Bool) {
            guard !isAnimating else { return }
            isAnimating = true
            
            print("\n🔄 PERFORMING SIMPLIFIED AXIS ROTATION")
            print("   Axis: \(axis)")
            print("   Slice: \(sliceIndex)")
            print("   Clockwise: \(clockwise)")
            
            // Use the existing rotation functions for standard axes
            if axis.x != 0 && axis.y == 0 && axis.z == 0 {
                // X-axis rotation
                print("   🔄 Using X-axis rotation function")
                rotateColumn(sliceIndex, clockwise: clockwise)
                return
            } else if axis.x == 0 && axis.y != 0 && axis.z == 0 {
                // Y-axis rotation
                print("   🔄 Using Y-axis rotation function")
                rotateRow(sliceIndex, clockwise: clockwise)
                return
            } else if axis.x == 0 && axis.y == 0 && axis.z != 0 {
                // Z-axis rotation
                print("   🔄 Using Z-axis rotation function")
                rotateLayer(sliceIndex, clockwise: clockwise)
                return
            }
            
            // Fallback to arbitrary axis rotation for non-standard axes
            print("   🔄 Using arbitrary axis rotation")
            
            // Determine which pieces to rotate based on the axis and slice
            let piecesToRotate: [CubePiece]
            let rotationCenter: SCNVector3
            
            let absX = abs(axis.x)
            let absY = abs(axis.y)
            let absZ = abs(axis.z)
            
            if absX > absY && absX > absZ {
                // X-axis rotation - rotate pieces with same X coordinate (Y-Z plane slice)
                piecesToRotate = getCubePiecesInColumn(sliceIndex)
                rotationCenter = SCNVector3(Float(sliceIndex - 1) * 0.34, 0, 0)
                print("   🔄 X-axis rotation: rotating X-slice \(sliceIndex)")
            } else if absY > absX && absY > absZ {
                // Y-axis rotation - rotate pieces with same Y coordinate (X-Z plane slice)
                piecesToRotate = getCubePiecesInRow(sliceIndex)
                rotationCenter = SCNVector3(0, Float(sliceIndex - 1) * 0.34, 0)
                print("   🔄 Y-axis rotation: rotating Y-slice \(sliceIndex)")
            } else {
                // Z-axis rotation - rotate pieces with same Z coordinate (X-Y plane slice)
                piecesToRotate = getCubePiecesInLayer(sliceIndex)
                rotationCenter = SCNVector3(0, 0, Float(sliceIndex - 1) * 0.34)
                print("   🔄 Z-axis rotation: rotating Z-slice \(sliceIndex)")
            }
            
            print("   📦 Found \(piecesToRotate.count) pieces to rotate")
            
            // Create rotation parent at the center
            let rotationParent = SCNNode()
            rotationParent.position = rotationCenter
            sceneView?.scene?.rootNode.addChildNode(rotationParent)
            
            // Move nodes to rotation parent
            for piece in piecesToRotate {
                let worldPos = piece.node.worldPosition
                piece.node.removeFromParentNode()
                rotationParent.addChildNode(piece.node)
                
                if let scene = self.sceneView?.scene {
                    let localPos = rotationParent.convertPosition(worldPos, from: scene.rootNode)
                    piece.node.position = localPos
                }
            }
            
            // Animate rotation
            let angle = clockwise ? Float.pi / 2 : -Float.pi / 2
            let rotation = SCNAction.rotate(by: CGFloat(angle), around: axis, duration: 0.25)
            
            rotationParent.runAction(rotation) { [weak self] in
                guard let self = self else { return }
                
                // Move nodes back to root with proper transform preservation
                for piece in piecesToRotate {
                    let finalTransform = piece.node.worldTransform
                    piece.node.removeFromParentNode()
                    self.sceneView?.scene?.rootNode.addChildNode(piece.node)
                    piece.node.transform = finalTransform
                    
                    // Update logical position (simplified - would need proper 3D rotation math)
                    self.updatePiecePositionAfterArbitraryRotation(piece: piece, axis: axis, clockwise: clockwise)
                }
                
                rotationParent.removeFromParentNode()
                self.isAnimating = false
                print("✅ Arbitrary axis rotation complete")
                print(String(repeating: "=", count: 60) + "\n")
            }
        }
        
        func updatePiecePositionAfterArbitraryRotation(piece: CubePiece, axis: SCNVector3, clockwise: Bool) {
            let oldPos = piece.position
            
            // For arbitrary axis rotations, we need to determine the new position based on
            // which slice was rotated and the rotation direction
            // Since we're doing 90-degree rotations, we can use the slice information
            
            // Determine which axis we're rotating around and update position accordingly
            let absX = abs(axis.x)
            let absY = abs(axis.y)
            let absZ = abs(axis.z)
            
            if absX > absY && absX > absZ {
                // X-axis rotation - we rotated a Y-slice, so pieces move in Y-Z plane
                // But we need to be more careful about which pieces actually moved
                print("  🔄 X-axis rotation: pieces in Y-slice should move in Y-Z plane")
                // For now, don't update positions - let the visual rotation handle it
                print("  📍 Piece position update: (\(oldPos.x), \(oldPos.y), \(oldPos.z)) → (position unchanged for arbitrary axis)")
                return
            } else if absY > absX && absY > absZ {
                // Y-axis rotation - we rotated an X-slice, so pieces move in X-Z plane
                print("  🔄 Y-axis rotation: pieces in X-slice should move in X-Z plane")
                // For now, don't update positions - let the visual rotation handle it
                print("  📍 Piece position update: (\(oldPos.x), \(oldPos.y), \(oldPos.z)) → (position unchanged for arbitrary axis)")
                return
            } else {
                // Z-axis rotation - we rotated a Y-slice, so pieces move in X-Y plane
                print("  🔄 Z-axis rotation: pieces in Y-slice should move in X-Y plane")
                // For now, don't update positions - let the visual rotation handle it
                print("  📍 Piece position update: (\(oldPos.x), \(oldPos.y), \(oldPos.z)) → (position unchanged for arbitrary axis)")
                return
            }
        }
        
        // MARK: - Vector Math Utilities
        
        func normalize(_ vector: SCNVector3) -> SCNVector3 {
            let length = sqrt(vector.x * vector.x + vector.y * vector.y + vector.z * vector.z)
            guard length > 0 else { return SCNVector3(0, 0, 0) }
            return SCNVector3(vector.x / length, vector.y / length, vector.z / length)
        }
        
        func crossProduct(_ a: SCNVector3, _ b: SCNVector3) -> SCNVector3 {
            return SCNVector3(
                a.y * b.z - a.z * b.y,
                a.z * b.x - a.x * b.z,
                a.x * b.y - a.y * b.x
            )
        }
        
        func determineRow(from point: CGPoint, in view: SCNView) -> Int {
            let hitResults = view.hitTest(point, options: nil)
            
            print("\n🔍 DETERMINING ROW from touch at screen point: (\(point.x), \(point.y))")
            print("   Hit test results count: \(hitResults.count)")
            
            if let firstHit = hitResults.first {
                print("   First hit node name: \(firstHit.node.name ?? "unnamed")")
                print("   Hit world position: \(firstHit.worldCoordinates)")
                
                // Extract position from node name
                if let nodeName = firstHit.node.name, nodeName.hasPrefix("cube_") {
                    let components = nodeName.replacingOccurrences(of: "cube_", with: "").split(separator: "_")
                    if components.count == 3,
                       let y = Int(components[1]) {
                        print("   🎯 HIT CUBE with CURRENT logical position: (\(components[0]), \(y), \(components[2]))")
                        print("   ✅ Using row (y): \(y)")
                        return y
                    }
                }
            }
            
            let normalizedY = point.y / view.bounds.height
            let row = normalizedY < 0.4 ? 0 : (normalizedY > 0.6 ? 2 : 1)
            print("   ⚠️ Using FALLBACK - normalized Y: \(normalizedY) → row: \(row)")
            return row
        }
        
        func determineColumn(from point: CGPoint, in view: SCNView) -> Int {
            let hitResults = view.hitTest(point, options: nil)
            
            print("\n🔍 DETERMINING COLUMN from touch at screen point: (\(point.x), \(point.y))")
            print("   Hit test results count: \(hitResults.count)")
            
            if let firstHit = hitResults.first {
                print("   First hit node name: \(firstHit.node.name ?? "unnamed")")
                print("   Hit world position: \(firstHit.worldCoordinates)")
                
                // Extract position from node name
                if let nodeName = firstHit.node.name, nodeName.hasPrefix("cube_") {
                    let components = nodeName.replacingOccurrences(of: "cube_", with: "").split(separator: "_")
                    if components.count == 3,
                       let x = Int(components[0]) {
                        print("   🎯 HIT CUBE with CURRENT logical position: (\(x), \(components[1]), \(components[2]))")
                        print("   ✅ Using column (x): \(x)")
                        return x
                    }
                }
            }
            
            let normalizedX = point.x / view.bounds.width
            let col = normalizedX < 0.4 ? 0 : (normalizedX > 0.6 ? 2 : 1)
            print("   ⚠️ Using FALLBACK - normalized X: \(normalizedX) → column: \(col)")
            return col
        }
        
        func rotateRow(_ row: Int, clockwise: Bool) {
            print("🔄 rotateRow called with row: \(row), clockwise: \(clockwise)")
            print("🔄 isAnimating: \(isAnimating)")
            
            guard !isAnimating else {
                print("❌ Rotation blocked - already animating")
                return 
            }
            isAnimating = true
            print("✅ Starting row rotation animation")
            
            print("\n" + String(repeating: "=", count: 60))
            print("🔄 ROTATING ROW \(row) \(clockwise ? "CLOCKWISE (Y-axis)" : "COUNTER-CLOCKWISE (Y-axis)")")
            print(String(repeating: "=", count: 60))
            
            // Get pieces in this row
            let piecesInRow = getCubePiecesInRow(row)
            
            print("📦 Found \(piecesInRow.count) pieces in row \(row):")
            for piece in piecesInRow {
                print("  - Piece at position (\(piece.position.x), \(piece.position.y), \(piece.position.z))")
                print("    World position: \(piece.node.worldPosition)")
            }
            
            // Create rotation parent at the center of the row
            let rotationParent = SCNNode()
            let offset: Float = 0.34 // cubeSize + spacing
            rotationParent.position = SCNVector3(0, Float(row - 1) * offset, 0)
            sceneView?.scene?.rootNode.addChildNode(rotationParent)
            
            // Move nodes to rotation parent (convert to local coordinates)
            for piece in piecesInRow {
                let worldPos = piece.node.worldPosition
                piece.node.removeFromParentNode()
                rotationParent.addChildNode(piece.node)
                
                // Convert world position to local position in rotation parent
                if let scene = self.sceneView?.scene {
                    let localPos = rotationParent.convertPosition(worldPos, from: scene.rootNode)
                    piece.node.position = localPos
                }
            }
            
            // Animate rotation around Y axis
            let angle = clockwise ? -Float.pi / 2 : Float.pi / 2
            let rotation = SCNAction.rotateBy(x: 0, y: CGFloat(angle), z: 0, duration: 0.25)
            
            print("🎬 Starting rotation animation with angle: \(angle)")
            rotationParent.runAction(rotation) { [weak self] in
                print("🎬 Rotation animation completed")
                guard let self = self else { return }
                
                // Move nodes back to root with proper transform preservation
                for piece in piecesInRow {
                    // Get the final transform in world space
                    let finalTransform = piece.node.worldTransform
                    
                    // Remove from parent and add to root
                    piece.node.removeFromParentNode()
                    self.sceneView?.scene?.rootNode.addChildNode(piece.node)
                    
                    // Apply the world transform
                    piece.node.transform = finalTransform
                    
                    // Update logical position after rotation around Y
                    let (x, y, z) = piece.position
                    let oldPos = piece.position
                    if clockwise {
                        piece.position = (z, y, 2 - x)
                    } else {
                        piece.position = (2 - z, y, x)
                    }
                    print("  📍 Piece moved: (\(oldPos.x), \(oldPos.y), \(oldPos.z)) → (\(piece.position.x), \(piece.position.y), \(piece.position.z))")
                    print("    New world position: \(piece.node.worldPosition)")
                }
                
                rotationParent.removeFromParentNode()
                self.isAnimating = false
                print("✅ Row rotation complete")
                print(String(repeating: "=", count: 60) + "\n")
            }
        }
        
        func rotateColumn(_ column: Int, clockwise: Bool) {
            print("🔄 rotateColumn called with column: \(column), clockwise: \(clockwise)")
            print("🔄 isAnimating: \(isAnimating)")
            
            guard !isAnimating else { 
                print("❌ Rotation blocked - already animating")
                return 
            }
            isAnimating = true
            print("✅ Starting column rotation animation")
            
            print("\n" + String(repeating: "=", count: 60))
            print("🔄 ROTATING COLUMN \(column) \(clockwise ? "CLOCKWISE (X-axis)" : "COUNTER-CLOCKWISE (X-axis)")")
            print(String(repeating: "=", count: 60))
            
            // Get pieces in this column
            let piecesInColumn = getCubePiecesInColumn(column)
            
            print("📦 Found \(piecesInColumn.count) pieces in column \(column):")
            for piece in piecesInColumn {
                print("  - Piece at position (\(piece.position.x), \(piece.position.y), \(piece.position.z))")
                print("    World position: \(piece.node.worldPosition)")
            }
            
            // Create rotation parent at the center of the column
            let rotationParent = SCNNode()
            let offset: Float = 0.34 // cubeSize + spacing
            rotationParent.position = SCNVector3(Float(column - 1) * offset, 0, 0)
            sceneView?.scene?.rootNode.addChildNode(rotationParent)
            
            // Move nodes to rotation parent (convert to local coordinates)
            for piece in piecesInColumn {
                let worldPos = piece.node.worldPosition
                piece.node.removeFromParentNode()
                rotationParent.addChildNode(piece.node)
                
                // Convert world position to local position in rotation parent
                if let scene = self.sceneView?.scene {
                    let localPos = rotationParent.convertPosition(worldPos, from: scene.rootNode)
                    piece.node.position = localPos
                }
            }
            
            // Animate rotation around X axis
            let angle = clockwise ? Float.pi / 2 : -Float.pi / 2
            let rotation = SCNAction.rotateBy(x: CGFloat(angle), y: 0, z: 0, duration: 0.25)
            
            print("🎬 Starting rotation animation with angle: \(angle)")
            rotationParent.runAction(rotation) { [weak self] in
                print("🎬 Rotation animation completed")
                guard let self = self else { return }
                
                // Move nodes back to root with proper transform preservation
                for piece in piecesInColumn {
                    // Get the final transform in world space
                    let finalTransform = piece.node.worldTransform
                    
                    // Remove from parent and add to root
                    piece.node.removeFromParentNode()
                    self.sceneView?.scene?.rootNode.addChildNode(piece.node)
                    
                    // Apply the world transform
                    piece.node.transform = finalTransform
                    
                    // Update logical position after rotation around X
                    let (x, y, z) = piece.position
                    let oldPos = piece.position
                    if clockwise {
                        piece.position = (x, 2 - z, y)
                    } else {
                        piece.position = (x, z, 2 - y)
                    }
                    print("  📍 Piece moved: (\(oldPos.x), \(oldPos.y), \(oldPos.z)) → (\(piece.position.x), \(piece.position.y), \(piece.position.z))")
                    print("    New world position: \(piece.node.worldPosition)")
                }
                
                rotationParent.removeFromParentNode()
                self.isAnimating = false
                print("✅ Column rotation complete")
                print(String(repeating: "=", count: 60) + "\n")
            }
        }
        
        func rotateLayer(_ layer: Int, clockwise: Bool) {
            print("🔄 rotateLayer called with layer: \(layer), clockwise: \(clockwise)")
            print("🔄 isAnimating: \(isAnimating)")
            
            guard !isAnimating else { 
                print("❌ Rotation blocked - already animating")
                return 
            }
            isAnimating = true
            print("✅ Starting layer rotation animation")
            
            print("\n" + String(repeating: "=", count: 60))
            print("🔄 ROTATING LAYER \(layer) \(clockwise ? "CLOCKWISE (Z-axis)" : "COUNTER-CLOCKWISE (Z-axis)")")
            print(String(repeating: "=", count: 60))
            
            // Get pieces in this layer
            let piecesInLayer = getCubePiecesInLayer(layer)
            
            print("📦 Found \(piecesInLayer.count) pieces in layer \(layer):")
            for piece in piecesInLayer {
                print("  - Piece at position (\(piece.position.x), \(piece.position.y), \(piece.position.z))")
                print("    World position: \(piece.node.worldPosition)")
            }
            
            // Create rotation parent at the center of the layer
            let rotationParent = SCNNode()
            let offset: Float = 0.34 // cubeSize + spacing
            rotationParent.position = SCNVector3(0, 0, Float(layer - 1) * offset)
            sceneView?.scene?.rootNode.addChildNode(rotationParent)
            
            // Move nodes to rotation parent (convert to local coordinates)
            for piece in piecesInLayer {
                let worldPos = piece.node.worldPosition
                piece.node.removeFromParentNode()
                rotationParent.addChildNode(piece.node)
                
                // Convert world position to local position in rotation parent
                if let scene = self.sceneView?.scene {
                    let localPos = rotationParent.convertPosition(worldPos, from: scene.rootNode)
                    piece.node.position = localPos
                }
            }
            
            // Animate rotation around Z axis
            let angle = clockwise ? Float.pi / 2 : -Float.pi / 2
            let rotation = SCNAction.rotateBy(x: 0, y: 0, z: CGFloat(angle), duration: 0.25)
            
            print("🎬 Starting rotation animation with angle: \(angle)")
            rotationParent.runAction(rotation) { [weak self] in
                print("🎬 Rotation animation completed")
                guard let self = self else { return }
                
                // Move nodes back to root with proper transform preservation
                for piece in piecesInLayer {
                    // Get the final transform in world space
                    let finalTransform = piece.node.worldTransform
                    
                    // Remove from parent and add to root
                    piece.node.removeFromParentNode()
                    self.sceneView?.scene?.rootNode.addChildNode(piece.node)
                    
                    // Apply the world transform
                    piece.node.transform = finalTransform
                    
                    // Update logical position after rotation around Z
                    let (x, y, z) = piece.position
                    let oldPos = piece.position
                    if clockwise {
                        piece.position = (2 - y, x, z)
                    } else {
                        piece.position = (y, 2 - x, z)
                    }
                    print("  📍 Piece moved: (\(oldPos.x), \(oldPos.y), \(oldPos.z)) → (\(piece.position.x), \(piece.position.y), \(piece.position.z))")
                    print("    New world position: \(piece.node.worldPosition)")
                }
                
                rotationParent.removeFromParentNode()
                self.isAnimating = false
                print("✅ Layer rotation complete")
                print(String(repeating: "=", count: 60) + "\n")
            }
        }
    }
    
    private func createScene(context: Context) -> SCNScene {
        let scene = SCNScene()
        
        let cubeSize: CGFloat = 0.32
        let spacing: CGFloat = 0.02
        let offset = cubeSize + spacing
        
        // Create 27 small cubes (3x3x3)
        for x in 0..<3 {
            for y in 0..<3 {
                for z in 0..<3 {
                    let smallCube = SCNBox(width: cubeSize, height: cubeSize, length: cubeSize, chamferRadius: 0.02)
                    let node = SCNNode(geometry: smallCube)
                    node.name = "cube_\(x)_\(y)_\(z)"
                    
                    // Position
                    node.position = SCNVector3(
                        CGFloat(x) * offset - offset,
                        CGFloat(y) * offset - offset,
                        CGFloat(z) * offset - offset
                    )
                    
                    // Create materials for each face
                    var materials: [SCNMaterial] = []
                    
                    // Determine colors based on position
                    let faceColors = context.coordinator.cube.faceColors
                    
                    // Right (+X) - Green (faceColors[1])
                    let rightMat = SCNMaterial()
                    rightMat.diffuse.contents = UIColor(faceColors[1])
                    rightMat.lightingModel = .phong
                    materials.append(rightMat)
                    
                    // Left (-X) - Yellow (faceColors[3])
                    let leftMat = SCNMaterial()
                    leftMat.diffuse.contents = UIColor(faceColors[3])
                    leftMat.lightingModel = .phong
                    materials.append(leftMat)
                    
                    // Top (+Y) - Orange (faceColors[4])
                    let topMat = SCNMaterial()
                    topMat.diffuse.contents = UIColor(faceColors[4])
                    topMat.lightingModel = .phong
                    materials.append(topMat)
                    
                    // Bottom (-Y) - Red (faceColors[2])
                    let bottomMat = SCNMaterial()
                    bottomMat.diffuse.contents = UIColor(faceColors[2])
                    bottomMat.lightingModel = .phong
                    materials.append(bottomMat)
                    
                    // Front (+Z) - Blue (faceColors[0])
                    let frontMat = SCNMaterial()
                    frontMat.diffuse.contents = UIColor(faceColors[0])
                    frontMat.lightingModel = .phong
                    materials.append(frontMat)
                    
                    // Back (-Z) - Pink (faceColors[5])
                    let backMat = SCNMaterial()
                    backMat.diffuse.contents = UIColor(faceColors[5])
                    backMat.lightingModel = .phong
                    materials.append(backMat)
                    
                    smallCube.materials = materials
                    scene.rootNode.addChildNode(node)
                }
            }
        }
        
        // Add lighting
        let lightNode = SCNNode()
        lightNode.light = SCNLight()
        lightNode.light!.type = .omni
        lightNode.light!.intensity = 1000
        lightNode.position = SCNVector3(x: 3, y: 3, z: 3)
        scene.rootNode.addChildNode(lightNode)
        
        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light!.type = .ambient
        ambientLight.light!.intensity = 500
        scene.rootNode.addChildNode(ambientLight)
        
        // Add camera
        let cameraNode = SCNNode()
        cameraNode.name = "camera"
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(x: 2, y: 2, z: 4)
        cameraNode.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(cameraNode)
        
        return scene
    }
}

// MARK: - Main Content View
struct ContentView: View {
    @StateObject private var cube = RubiksCube()
    
    var body: some View {
        ZStack {
            Color.white.edgesIgnoringSafeArea(.all)
            
            Interactive3DCubeView(cube: cube)
                .edgesIgnoringSafeArea(.all)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
    ContentView()
    }
}
