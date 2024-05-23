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

    override init() {
        model = SurgeryModel()

        super.init()

        model.delegate = self
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
        guard let modelURL = Bundle.main.url(forResource: "sample-femur", withExtension: "usdz") else {
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

        // temporary hack to get the model sized properly
        //modelNode.scaleToWidth(centimeters: 20)
        // make it translucent
        modelNode.opacity = 0.2
        // rotate the model up and tilt it slightly.  remember, the femur comes from the upper leg, so the base points up
//        modelNode.rotate(x: 0, y: 0, z: 0)

        let transform = frame.camera.transform
        overlayNode = modelNode // Store the reference
        
//        Fixing overlay at position SCNVector3(x: -0.020270478, y: -0.0797465, z: -0.13184097) and orientation SCNVector4(x: 0.998327, y: -0.0042214324, z: 0.056730166, w: 0.0103404)

        modelNode.position = SCNVector3(x: -0.020270478, y: -0.0797465, z: -0.13184097)
        modelNode.orientation = SCNVector4(x: 0.998327, y: -0.0042214324, z: 0.056730166, w: 0.0103404)
        
        //getPositionInFrontOfCamera(cameraTransform: transform, distanceMeters: 0.2)

        self.logger.info("Adding overlay to the scene")
        scene.rootNode.addChildNode(modelNode)

        let axis1 = createAxis()
        axis1.position = SCNVector3(x: 0.0, y: 0, z: 0)
        axis1.eulerAngles = SCNVector3(x: Float.pi/2, y: 0, z: 0)
        modelNode.addChildNode(axis1)

        addedOverlayToScene = true
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
        guard let frame = await self.sceneView?.session.currentFrame else {
            throw logger.logAndGetError("Could not get current AR frame")
        }
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let sessionId = dateFormatter.string(from: Date())
        // use a fake session ID
        let request = try makeTrackingRequest(sessionId: sessionId, frame: frame)
        try saveTrackingRequest(request)
    }
    
    func stopSession() async throws {
        if let trackingTask = trackingTask, !trackingTask.isCancelled {
            trackingTask.cancel()
            await trackingTask.value
        } else {
            logger.warning("Session did not have a tracking task")
        }
        removeOverlayModel()
        let sessionId = sessionId
        self.sessionId = nil
        trackingCount = 0
        // todo: stop the AR session and set adjustedWorldOrigin to false

        await MainActor.run {
            model.phase = .done
        }

        // todo: notify the server so it can close the session
    }
    
    /// Begins the ongoing process of tracking the position of the bone.  This makes a single pose request to the server, so this is a long-running operation
    func startTracking() async throws {

    }
    

}

