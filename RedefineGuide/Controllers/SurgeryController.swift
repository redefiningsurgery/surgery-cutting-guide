import SwiftUI
import SceneKit
import ARKit

class SurgeryController: NSObject {

    let model: SurgeryModel
    private var logger = RedefineLogger("ARViewController")
    private var sceneView: ARSCNView? = nil
    private var scene: SCNScene? = nil

    override init() {
        self.model = SurgeryModel()

        super.init()

        self.model.delegate = self
    }
    
    func pause() {
        self.sceneView?.session.pause()
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
        if let arView = self.sceneView {
            logger.warning("ARView was previously created.  Returning that.")
            return arView
        }
        let sceneView = ARSCNView()
        sceneView.debugOptions = [
            .showWorldOrigin,
        ]
        sceneView.delegate = self
        
        let scene = SCNScene()
        sceneView.scene = scene
        
        self.scene = scene
        self.sceneView = sceneView
        startSession()
        
        return sceneView
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
