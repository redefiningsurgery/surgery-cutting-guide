import SwiftUI
import SceneKit
import ARKit

class ARViewController: NSObject {

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

extension ARViewController: ARSCNViewDelegate {

    /// temporary functionality to add a box to the scene
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
        
        logger.info("Placing a box at the detected plane")
        
        // Create a virtual object (e.g., a box) to place on the detected surface
        let box = SCNBox(width: 0.2, height: 0.2, length: 0.2, chamferRadius: 0)
        
        let material = SCNMaterial()
        material.diffuse.contents = UIColor.blue // Set the color of the box
        box.materials = [material]
        
        // Create a node for the box
        let boxNode = SCNNode(geometry: box)
        
        // Position the box node on the plane anchor
        boxNode.position = SCNVector3(
            planeAnchor.center.x,
            0, // Assume the box's bottom should rest on the plane, hence y is 0
            planeAnchor.center.z)
        
        // Add the box node to the detected plane node
        node.addChildNode(boxNode)
    }

}


extension ARViewController: SurgeryModelDelegate {
    
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
        
        sceneView.session.run(arConfiguration)
        
        return sceneView
    }

    func addSomething() throws {
        guard let scene = scene else {
            logger.error("scene didn't exist")
            return
        }
        
        logger.info("Adding something")
        let cubeNode = SCNNode(geometry: SCNBox(width: 0.1, height: 0.1, length: 0.1, chamferRadius: 0))
        cubeNode.position = SCNVector3(0, 0, -0.2) // SceneKit/AR coordinates are in meters
        scene.rootNode.addChildNode(cubeNode)
    }
    
    func addModel(_ name: String) throws {
        guard let arView = sceneView else {
            throw logger.logAndGetError("ARView didn't exist so model can't be added")
        }
        
        guard let modelURL = Bundle.main.url(forResource: name, withExtension: "usdz") else {
            throw logger.logAndGetError("Could not find model file for \(name)")
        }
        
        let modelNode = SCNNode()
        let modelScene = try SCNScene(url: modelURL, options: nil)
        for child in modelScene.rootNode.childNodes {
            modelNode.addChildNode(child)
        }
        
        modelNode.scale = SCNVector3(0.01, 0.01, 0.01)

        if let cameraNode = arView.pointOfView {
            modelNode.position = SCNVector3(cameraNode.position.x, cameraNode.position.y, cameraNode.position.z - 1) // Adjust as needed
        }

        arView.scene.rootNode.addChildNode(modelNode)
        
        logger.info("Added model")
    }
}
