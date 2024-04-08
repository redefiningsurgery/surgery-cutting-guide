import SwiftUI
import SceneKit
import ARKit
import Combine

class SurgeryController: NSObject {

    let model: SurgeryModel
    private var logger = RedefineLogger("ARViewController")
    private var sceneView: ARSCNView? = nil
    private var scene: SCNScene? = nil
    private var leadingCube: SCNNode?
    private var showCubeSubscription: AnyCancellable?

    override init() {
        model = SurgeryModel()

        super.init()

        model.delegate = self
        showCubeSubscription = model.$showLeadingCube
            .sink { [weak self] newValue in
                print("showCube changed to \(newValue)")
                self?.handleShowCubeChanged(newValue)
            }
    }
    
    private func handleShowCubeChanged(_ show: Bool) {
        guard sceneView != nil else {
            return
        }
        if show {
            addLeadingCube()
        } else {
            removeLeadingCube()
        }
    }
    
    func pause() {
        self.sceneView?.session.pause()
        logger.info("Stopped AR session")
    }
    
    func resetWorldOrigin() {
        pause()
        startSession()
    }
    
    private func startSession() {
        guard let sceneView = sceneView else {
            logger.error("No sceneView.  Cannot start ARSession")
            return
        }
        let arConfiguration = ARWorldTrackingConfiguration()
        arConfiguration.frameSemantics.insert(.sceneDepth)
        arConfiguration.planeDetection = .horizontal
        arConfiguration.isAutoFocusEnabled = true

        sceneView.session.delegate = self
        sceneView.session.run(arConfiguration, options: [.resetTracking])
        logger.info("Started AR session")
    }
}

extension SurgeryController: ARSCNViewDelegate {
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        DispatchQueue.main.async {
            if let leadingCube = self.leadingCube {
                self.updateCubePosition()
            }
        }
    }
}

extension SurgeryController: ARSessionDelegate {
    /// Called every time the ARFrame is updated
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // frame.sceneDepth?.depthMap
    }
}


extension SurgeryController: SurgeryModelDelegate {
    
    /// Creates the ARSCNView used to show the camera and added scenery
    func getARView() -> ARSCNView {
        if let sceneView = self.sceneView {
            logger.warning("sceneView was previously created.  Returning that.")
            return sceneView
        }
        let sceneView = ARSCNView()
        sceneView.automaticallyUpdatesLighting = true
        sceneView.debugOptions = [
            .showWorldOrigin,
        ]
        sceneView.delegate = self
        
        let scene = SCNScene()
        sceneView.scene = scene
        
        self.scene = scene
        self.sceneView = sceneView
        startSession()
     
        if model.showLeadingCube {
            addLeadingCube()
        }
        
        return sceneView
    }
    
    func addLeadingCube() {
        // If the cube node already exists, just update its position
        if let existingNode = leadingCube {
            updateCubePosition()
            return
        }
        // Otherwise, create a new cube node and add it to the scene
        let cubeGeometry = SCNBox(width: 0.1, height: 0.1, length: 0.1, chamferRadius: 0)
        let material = SCNMaterial()
        // Apply a texture
        material.diffuse.contents = UIImage(named: "wood-texture")
        // Make the material slightly translucent
        material.transparency = 0.5
        // Apply the material to all sides of the cube
        cubeGeometry.materials = [material, material, material, material, material, material]

        let newNode = SCNNode(geometry: cubeGeometry)
        leadingCube = newNode // Store the reference
        sceneView!.scene.rootNode.addChildNode(newNode)
        
        updateCubePosition()
    }

    func updateCubePosition() {
        guard let currentFrame = sceneView?.session.currentFrame else {
            logger.warning("Could not get current ARFrame to update position of cube")
            return
        }
        guard let leadingCube = leadingCube else {
            logger.warning("No leading cube to update position for")
            return
        }
        
        // Use the camera's transform to get its current orientation and position
        let transform = currentFrame.camera.transform
        let cameraPosition = SCNVector3(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
        
        // Calculate the forward vector from the camera transform
        let forward = SCNVector3(-transform.columns.2.x, -transform.columns.2.y, -transform.columns.2.z)
        let adjustedForward = forward.normalized() * 0.5 // Adjust to be 0.5 meters in front
        
        // Update the cube's position to be 0.5 meters in front of the camera
        leadingCube.position = cameraPosition + adjustedForward
    }
    
    func removeLeadingCube() {
        leadingCube?.removeFromParentNode()
        leadingCube = nil
    }
    
    /// Adds something to the real-world location from the point tapped on the sceneView
    func addSomething(point: CGPoint) throws {
        guard let sceneView = sceneView else {
            logger.error("sceneView didn't exist")
            return
        }
        
        guard let query = sceneView.raycastQuery(from: point, allowing: .estimatedPlane, alignment: .horizontal) else {
            return
        }
        
        // Perform the raycast
        let results = sceneView.session.raycast(query)
        
        // Check if the raycast found a surface
        if let firstResult = results.first {
            // Create a new SCNBox (a 3D box)
            let boxGeometry = SCNBox(width: 0.1, height: 0.1, length: 0.1, chamferRadius: 0.0)
            let material = SCNMaterial()
            material.diffuse.contents = UIColor.blue // Example: Set the box color to blue
            boxGeometry.materials = [material]
            
            let boxNode = SCNNode(geometry: boxGeometry)
            
            // Set the position of the boxNode using the firstResult's worldTransform
            boxNode.simdTransform = firstResult.worldTransform
            
            // Adjust Y position to make the box sit on the plane
            boxNode.position.y += Float(boxGeometry.height / 2)
            
            // Add the box node to the scene
            sceneView.scene.rootNode.addChildNode(boxNode)
            logger.info("Added box")
        } else {
            logger.warning("No hit result")
        }
    }
}

extension SCNVector3 {
    func normalized() -> SCNVector3 {
        let length = sqrt(x * x + y * y + z * z)
        return SCNVector3(x / length, y / length, z / length)
    }
    
    static func +(lhs: SCNVector3, rhs: SCNVector3) -> SCNVector3 {
        return SCNVector3(lhs.x + rhs.x, lhs.y + rhs.y, lhs.z + rhs.z)
    }
    
    static func *(vector: SCNVector3, scalar: Float) -> SCNVector3 {
        return SCNVector3(vector.x * scalar, vector.y * scalar, vector.z * scalar)
    }
}
