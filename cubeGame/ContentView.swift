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
    
    let faceColors: [Color] = [.red, .orange, .yellow, .white, .green, .blue]
    
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
        context.coordinator.initializeCubePieces(scene: scene)
        
        // Add pan gesture for rotation control
        let panGesture = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        panGesture.minimumNumberOfTouches = 1
        panGesture.maximumNumberOfTouches = 2
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
        var cubePieces: [CubePiece] = []
        var isHoldingCube = false
        var isTwoFingerGesture = false
        var swipeStartLocation: CGPoint?
        var lastSwipeDistance: CGFloat = 0
        var currentCameraAngle: (x: Float, y: Float) = (0.3, 0.3)
        var isAnimating = false
        
        init(cube: RubiksCube) {
            self.cube = cube
        }
        
        func initializeCubePieces(scene: SCNScene) {
            cubePieces = []
            
            // Create 27 cube pieces with permanent colors
            for x in 0..<3 {
                for y in 0..<3 {
                    for z in 0..<3 {
                        let nodeName = "cube_\(x)_\(y)_\(z)"
                        if let node = scene.rootNode.childNode(withName: nodeName, recursively: true) {
                            // Assign permanent colors based on initial position
                            var colors: [Color] = []
                            
                            // Right face (x=2)
                            colors.append(x == 2 ? cube.faceColors[1] : .clear)
                            // Left face (x=0)  
                            colors.append(x == 0 ? cube.faceColors[3] : .clear)
                            // Top face (y=2)
                            colors.append(y == 2 ? cube.faceColors[4] : .clear)
                            // Bottom face (y=0)
                            colors.append(y == 0 ? cube.faceColors[2] : .clear)
                            // Front face (z=2)
                            colors.append(z == 2 ? cube.faceColors[0] : .clear)
                            // Back face (z=0)
                            colors.append(z == 0 ? cube.faceColors[5] : .clear)
                            
                            let piece = CubePiece(position: (x, y, z), colors: colors, node: node)
                            cubePieces.append(piece)
                        }
                    }
                }
            }
            
            print("✅ Initialized \(cubePieces.count) cube pieces")
        }
        
        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let sceneView = sceneView else { return }
            
            let location = gesture.location(in: sceneView)
            let touchCount = gesture.numberOfTouches
            
            switch gesture.state {
            case .began:
                if touchCount == 1 {
                    isHoldingCube = true
                    isTwoFingerGesture = false
                }
                
            case .changed:
                if touchCount == 2 && !isTwoFingerGesture {
                    isTwoFingerGesture = true
                    isHoldingCube = false
                    swipeStartLocation = location
                    lastSwipeDistance = 0
                }
                
                if touchCount == 1 && isHoldingCube {
                    rotateCameraView(gesture: gesture, in: sceneView)
                } else if touchCount == 2 && isTwoFingerGesture, let startLocation = swipeStartLocation {
                    let deltaX = location.x - startLocation.x
                    let deltaY = location.y - startLocation.y
                    
                    // Determine which direction has more movement
                    if abs(deltaX) > abs(deltaY) {
                        // Horizontal swipe - rotate rows
                        let threshold: CGFloat = 60
                        let rotations = Int(abs(deltaX) / threshold)
                        let lastRotations = Int(abs(lastSwipeDistance) / threshold)
                        
                        if rotations > lastRotations {
                            let row = determineRow(from: startLocation, in: sceneView)
                            print("Swipe direction: \(deltaX > 0 ? "RIGHT" : "LEFT")")
                            // Swipe RIGHT = rotate right, Swipe LEFT = rotate left
                            if deltaX > 0 {
                                rotateRow(row, clockwise: true)
                            } else {
                                rotateRow(row, clockwise: false)
                            }
                        }
                        lastSwipeDistance = deltaX
                    } else {
                        // Vertical swipe - rotate columns
                        let threshold: CGFloat = 60
                        let rotations = Int(abs(deltaY) / threshold)
                        let lastRotations = Int(abs(lastSwipeDistance) / threshold)
                        
                        if rotations > lastRotations {
                            let column = determineColumn(from: startLocation, in: sceneView)
                            print("Swipe direction: \(deltaY > 0 ? "DOWN" : "UP")")
                            // Swipe DOWN = rotate down, Swipe UP = rotate up
                            if deltaY > 0 {
                                rotateColumn(column, clockwise: true)
                            } else {
                                rotateColumn(column, clockwise: false)
                            }
                        }
                        lastSwipeDistance = deltaY
                    }
                }
                
            case .ended, .cancelled:
                isHoldingCube = false
                isTwoFingerGesture = false
                swipeStartLocation = nil
                lastSwipeDistance = 0
                
            default:
                break
            }
        }
        
        func rotateCameraView(gesture: UIPanGestureRecognizer, in view: UIView) {
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
        
        func determineRow(from point: CGPoint, in view: SCNView) -> Int {
            let hitResults = view.hitTest(point, options: nil)
            
            print("\n🔍 DETERMINING ROW from touch at screen point: (\(point.x), \(point.y))")
            print("   Hit test results count: \(hitResults.count)")
            
            if let firstHit = hitResults.first {
                print("   First hit node: \(firstHit.node.name ?? "unnamed")")
                print("   Hit world position: \(firstHit.worldCoordinates)")
                
                if let nodeName = firstHit.node.name, nodeName.hasPrefix("cube_") {
                    let components = nodeName.components(separatedBy: "_")
                    if components.count >= 4, let x = Int(components[1]), let y = Int(components[2]), let z = Int(components[3]) {
                        print("   🎯 HIT CUBE at logical position: (\(x), \(y), \(z))")
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
                print("   First hit node: \(firstHit.node.name ?? "unnamed")")
                print("   Hit world position: \(firstHit.worldCoordinates)")
                
                if let nodeName = firstHit.node.name, nodeName.hasPrefix("cube_") {
                    let components = nodeName.components(separatedBy: "_")
                    if components.count >= 4, let x = Int(components[1]), let y = Int(components[2]), let z = Int(components[3]) {
                        print("   🎯 HIT CUBE at logical position: (\(x), \(y), \(z))")
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
            guard !isAnimating else { return }
            isAnimating = true
            
            print("\n" + String(repeating: "=", count: 60))
            print("🔄 ROTATING ROW \(row) \(clockwise ? "CLOCKWISE (Y-axis)" : "COUNTER-CLOCKWISE (Y-axis)")")
            print(String(repeating: "=", count: 60))
            
            // Get pieces in this row
            let piecesInRow = cubePieces.filter { $0.position.y == row }
            
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
            
            rotationParent.runAction(rotation) { [weak self] in
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
            guard !isAnimating else { return }
            isAnimating = true
            
            print("\n" + String(repeating: "=", count: 60))
            print("🔄 ROTATING COLUMN \(column) \(clockwise ? "CLOCKWISE (X-axis)" : "COUNTER-CLOCKWISE (X-axis)")")
            print(String(repeating: "=", count: 60))
            
            // Get pieces in this column
            let piecesInColumn = cubePieces.filter { $0.position.x == column }
            
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
            
            rotationParent.runAction(rotation) { [weak self] in
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
                    
                    // Right (+X)
                    let rightMat = SCNMaterial()
                    rightMat.diffuse.contents = UIColor(faceColors[1])
                    rightMat.lightingModel = .phong
                    materials.append(rightMat)
                    
                    // Left (-X)
                    let leftMat = SCNMaterial()
                    leftMat.diffuse.contents = UIColor(faceColors[3])
                    leftMat.lightingModel = .phong
                    materials.append(leftMat)
                    
                    // Top (+Y)
                    let topMat = SCNMaterial()
                    topMat.diffuse.contents = UIColor(faceColors[4])
                    topMat.lightingModel = .phong
                    materials.append(topMat)
                    
                    // Bottom (-Y)
                    let bottomMat = SCNMaterial()
                    bottomMat.diffuse.contents = UIColor(faceColors[2])
                    bottomMat.lightingModel = .phong
                    materials.append(bottomMat)
                    
                    // Front (+Z)
                    let frontMat = SCNMaterial()
                    frontMat.diffuse.contents = UIColor(faceColors[0])
                    frontMat.lightingModel = .phong
                    materials.append(frontMat)
                    
                    // Back (-Z)
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
