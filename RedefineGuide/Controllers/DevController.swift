import SwiftUI
import SceneKit
import SceneKit.ModelIO
import ARKit
import Combine
import SwiftProtobuf

// THIS IS A SILLY WAY FOR STEVE TO HACK ON THINGS WITHOUT DISRUPTING THE APP.  Please delete this later

class DevController: NSObject {
    let model: SurgeryModel
    private var logger = RedefineLogger("DevController")
    private var sceneView: ARSCNView? = nil
    private var scene: SCNScene? = nil
    private var overlayNode: SCNNode?
    private var showOverlaySubscription: AnyCancellable?
    private var sessionId: String? = nil
    private var trackingTask: Task<(), Never>? = nil
    /// The number of times the tracking has been updated.  Each time is a trip to the server
    private var trackingCount: Int = 0
    private var addedOverlayToScene: Bool = false
    private var axis1Material: SCNMaterial? = nil
    private var axis1: SCNNode? = nil
    private var axis2Material: SCNMaterial? = nil
    private var axis2: SCNNode? = nil
    private var cancellables: Set<AnyCancellable> = []

    @MainActor
    override init() {
        model = SurgeryModel()

        super.init()

        model.delegate = self
        Publishers.Merge6(model.$axis1X, model.$axis1Y, model.$axis1Z, model.$axis2X, model.$axis2Y, model.$axis2Z)
            .sink { [weak self] newValue in
                self?.updateAxisPosition()
            }
            .store(in: &cancellables)
    }
        
    func pause() {
        self.sceneView?.session.pause()
        logger.info("Stopped AR session")
    }
    
    private func startArSession() throws {
        guard let sceneView = sceneView else {
            throw logger.logAndGetError("No sceneView.  Cannot start ARSession")
        }
        let configuration = ARWorldTrackingConfiguration()
        configuration.frameSemantics.insert(.sceneDepth)
        configuration.frameSemantics.insert(.smoothedSceneDepth)
//        configuration.frameSemantics.insert(.personSegmentationWithDepth)
        configuration.sceneReconstruction = .mesh
        // https://developer.apple.com/documentation/arkit/arkit_in_ios/content_anchors/scanning_and_detecting_3d_objects
        configuration.planeDetection = .horizontal
        configuration.isAutoFocusEnabled = true
 
        sceneView.session.delegate = self
        sceneView.session.run(configuration, options: [.resetTracking])
        logger.info("Started AR session")
    }

    @MainActor
    func loadOverlay(frame: ARFrame, scene: SCNScene) throws {
        guard let modelURL = Bundle.main.url(forResource: "femur-3", withExtension: "usdz") else {
            throw logger.logAndGetError("Could not find model file")
        }

        let modelAsset = MDLAsset(url: modelURL)
        modelAsset.loadTextures()
        let modelObject = modelAsset.object(at: 0)

        // this causes the UI to freeze.  but I tried to put it in a background task and that didn't help. we'll have to handle this later
        let modelNode = SCNNode(mdlObject: modelObject)

        let (min, max) = modelNode.boundingBox
        let width = max.x - min.x
        let height = max.y - min.y
        let depth = max.z - min.z
        logger.info("CAD native dimensions: width=\(width), height=\(height), depth=\(depth)")

        modelNode.opacity = 0.8
        overlayNode = modelNode // Store the reference
        
        modelNode.position = SCNVector3(x: -0.015936472, y: -0.10953573, z: -0.13522644)
        modelNode.orientation = SCNQuaternion(-0.26126942, -0.010307378, 0.047436498, 0.9640445)
        
        //getPositionInFrontOfCamera(cameraTransform: transform, distanceMeters: 0.2)

        self.logger.info("Adding overlay to the scene")
        scene.rootNode.addChildNode(modelNode)

        let axis1 = createAxis()
        axis1.eulerAngles = SCNVector3(x: Float.pi/2, y: 0, z: 0)
        self.axis1Material = axis1.geometry!.firstMaterial!
        self.axis1 = axis1
        modelNode.addChildNode(axis1)

        let axis2 = createAxis()
        axis2.eulerAngles = SCNVector3(x: Float.pi/2, y: 0, z: 0)
        self.axis2Material = axis2.geometry!.firstMaterial!
        self.axis2 = axis2
        modelNode.addChildNode(axis2)

        updateAxisPosition()

        addedOverlayToScene = true
    }
    
    @MainActor
    func updateAxisPosition() {
        guard let axis1 = axis1, let axis2 = axis2 else {
            return
        }

        axis1.position = SCNVector3(x: model.axis1X, y: model.axis1Y, z: model.axis1Z)
        axis2.position = SCNVector3(x: model.axis2X, y: model.axis2Y, z: model.axis2Z)
        logger.info("Axis position: \(axis1.position)")
    }
    
    func removeOverlayModel() {
        if let overlayNode = self.overlayNode {
            logger.info("Removed overlay")
            overlayNode.removeFromParentNode()
            self.overlayNode = nil
            self.addedOverlayToScene = false
        }
    }
}

extension DevController: ARSCNViewDelegate {
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {

    }
}

extension DevController: ARSessionDelegate {
    
    /// Called every time the ARFrame is updated
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        DispatchQueue.main.async {
            if let scene = self.scene {
                if !self.addedOverlayToScene {
                    try? self.loadOverlay(frame: frame, scene: scene)
                }
            }
            if let axisMaterial = self.axis1Material, let depthData = frame.smoothedSceneDepth?.depthMap {
                // these were always nil
//                if let near = self.scene?.rootNode.camera?.zNear {
//                    print("Near: \(near)")
//                }
//                if let far = self.scene?.rootNode.camera?.zFar {
//                    print("Far: \(far)")
//                }
                
//            if let axisMaterial = self.axisMaterial, let depthData = frame.sceneDepth?.depthMap {
                setAxisMetalStuff(depthData, frame.camera.imageResolution, axisMaterial)
            }
        }
        // if this is the first frame in the session, adjust the world origin so the center is slightly in front of the phone
    }
}


extension DevController: SurgeryModelDelegate {
    
    /// Creates the ARSCNView used to show the camera and added scenery
    func getARView() throws -> ARSCNView {
        if let sceneView = self.sceneView {
            logger.warning("sceneView was previously created.  Returning that.")
            return sceneView
        }
        let sceneView = ARSCNView()
        sceneView.automaticallyUpdatesLighting = true
//        sceneView.debugOptions = [
//            .showWorldOrigin,
//        ]
        sceneView.delegate = self
        
        let scene = SCNScene()
        sceneView.scene = scene
        
        self.scene = scene
        self.sceneView = sceneView
        try startArSession()
        
        return sceneView
    }
    
    func resetWorldOrigin() throws {
        pause()
        try startArSession()
    }

    @MainActor
    func startSession() async throws {
    }
    
    // Saves request data to a file, which is useful when there is no connectivity to the server and you are willing to copy the files manually from the phone to the server
    func saveSnapshot() async throws {

    }
    
    func stopSession() async throws {

    }
    
    /// Begins the ongoing process of tracking the position of the bone.  This makes a single pose request to the server, so this is a long-running operation
    func startTracking() async throws {

    }
    

}

