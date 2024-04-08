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
}

extension SurgeryController: ARSCNViewDelegate {

    /// temporary functionality to add a box to each newly detected plane
//    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
//        guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
//        
//        logger.info("Placing a box at the detected plane")
//        
//        // Create a virtual object (e.g., a box) to place on the detected surface
//        let box = SCNBox(width: 0.2, height: 0.2, length: 0.2, chamferRadius: 0)
//        
//        let material = SCNMaterial()
//        material.diffuse.contents = UIColor.blue // Set the color of the box
//        box.materials = [material]
//        
//        // Create a node for the box
//        let boxNode = SCNNode(geometry: box)
//        
//        // Position the box node on the plane anchor
//        boxNode.position = SCNVector3(
//            planeAnchor.center.x,
//            0, // Assume the box's bottom should rest on the plane, hence y is 0
//            planeAnchor.center.z)
//        
//        // Add the box node to the detected plane node
//        node.addChildNode(boxNode)
//    }

}

extension SurgeryController: ARSessionDelegate {
    /// Called every time the ARFrame is updated
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // frame.sceneDepth?.depthMap
    }
}


extension SurgeryController: SurgeryModelDelegate {
    
    func getARView() -> ARSCNView {
        if let arView = self.sceneView {
            logger.warning("ARView was previously created.  Returning that.")
            return arView
        }
        let sceneView = ARSCNView()
        sceneView.delegate = self
        sceneView.showsStatistics = true // show fps and timing info
        sceneView.automaticallyUpdatesLighting = true // automatic lighting
        
        let scene = SCNScene()
        sceneView.scene = scene
        
        self.scene = scene
        self.sceneView = sceneView
        logger.info("Running AR session")
  
        let arConfiguration = ARWorldTrackingConfiguration()
        // arConfiguration.worldAlignment = .gravity
        arConfiguration.frameSemantics.insert(.sceneDepth)
        arConfiguration.planeDetection = .horizontal
//        arConfiguration.frameSemantics.insert(.bodyDetection)

        sceneView.session.delegate = self
        sceneView.session.run(arConfiguration)
        
        return sceneView
    }

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
