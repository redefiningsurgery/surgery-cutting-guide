import SwiftUI
import SceneKit
import SceneKit.ModelIO
import ARKit
import Combine
import SwiftProtobuf

let maxBoundingBoxSizeOfOverlayInMeters: Float = 0.1

class SurgeryController: NSObject {
    let model: SurgeryModel
    private var logger = RedefineLogger("SurgeryController")
    private var sceneView: ARSCNView? = nil
    private var scene: SCNScene? = nil
    private var overlayNode: SCNNode?
    private var pinGuideNode: SCNNode?
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
        // https://developer.apple.com/documentation/arkit/arkit_in_ios/content_anchors/scanning_and_detecting_3d_objects
        configuration.planeDetection = .horizontal
        configuration.isAutoFocusEnabled = true
 
        sceneView.session.delegate = self
        sceneView.session.run(configuration, options: [.resetTracking])
        logger.info("Started AR session")
    }

    func loadOverlay(_ data: Data) throws {
        let modelAsset = try loadMDLAsset(data)
        modelAsset.loadTextures()
        let modelObject = modelAsset.object(at: 0)

        // this causes the UI to freeze.  but I tried to put it in a background task and that didn't help. we'll have to handle this later
        let modelNode = SCNNode(mdlObject: modelObject)

        let (min, max) = modelNode.boundingBox
        let width = max.x - min.x
        let height = max.y - min.y
        let depth = max.z - min.z
        logger.info("CAD native dimensions: width=\(width), height=\(height), depth=\(depth)")

        guard width <= maxBoundingBoxSizeOfOverlayInMeters && height <= maxBoundingBoxSizeOfOverlayInMeters && depth <= maxBoundingBoxSizeOfOverlayInMeters else {
            throw logger.logAndGetError("Overlay CAD model was too big.  It needs adjusted.  Dimensions in meters: width=\(width), height=\(height), depth=\(depth)")
        }
        
        // temporary hack to get the model sized properly
        //modelNode.scaleToWidth(centimeters: 20)
        // make it translucent
        modelNode.opacity = 0.5
        // rotate the model up and tilt it slightly.  remember, the femur comes from the upper leg, so the base points up
        modelNode.rotate(x: 0, y: 0, z: 0)

        overlayNode = modelNode // Store the reference
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

extension SurgeryController: ARSCNViewDelegate {
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {

    }
}

extension SurgeryController: ARSessionDelegate {
    /// Called every time the ARFrame is updated
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        DispatchQueue.main.async {
            // add the overlay if necessary, and update its position during alignment to right in front of the camera
            if self.model.phase == .aligning, let overlayNode = self.overlayNode, let sceneView = self.sceneView {
                if !self.addedOverlayToScene {
                    self.logger.info("Adding overlay to the scene")
                    sceneView.scene.rootNode.addChildNode(overlayNode)
                    self.addedOverlayToScene = true
                }
                if overlayNode.parent == nil {
                    self.logger.error("OVERLAY GOT REMOVED DURING ALIGNMENT!!!!")
                }
                updateOverlayNodePositionAndOrientation(cameraTransform: frame.camera.transform, overlayNode: overlayNode, distanceMeters: 0.2)
                self.model.overlayBounds = overlayNode.getBoundingBoxInScreenCoords(in: sceneView)
            }
            // just a spot check because this might have happened.  if this doesn't occur for a while, remove it
            if self.addedOverlayToScene, self.overlayNode?.parent == nil {
                self.logger.error("OVERLAY GOT REMOVED FROM THE SCENE")
            }
        }
        // if this is the first frame in the session, adjust the world origin so the center is slightly in front of the phone
    }
}


extension SurgeryController: SurgeryModelDelegate {
    
    /// Creates the ARSCNView used to show the camera and added scenery
    func getARView() throws -> ARSCNView {
        if let sceneView = self.sceneView {
            // this occurs when ARViewContainer switches, which happens when the model's phase change
            logger.info("sceneView was previously created.  Returning that.")
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
    
    func executeRequest<T : Message>(of: T.Type, method: String, path: String, body: Data? = nil) async throws -> T {
        let urlString = "\(getServerUrl())/\(path)"
        guard let url = URL(string: urlString) else {
            throw logger.logAndGetError("Bad url: \(urlString)")
        }
        logger.info("\(method) \(urlString)")
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        
        let (data, response) = try await URLSession.shared.data(for: request)

        // Check the response code
        guard let httpResponse = response as? HTTPURLResponse else {
            throw logger.logAndGetError("Incorrect response type")
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            var errorDetail = "Bad response code: \(httpResponse.statusCode)"
            if let responseData = String(data: data, encoding: .utf8), !responseData.isEmpty {
                errorDetail += ", Message: \(responseData)"
            }
            throw logger.logAndGetError(errorDetail)
        }

        do {
            let output = try of.init(serializedData: data)
            return output
        } catch {
            throw logger.logAndGetError("Failed to deserialize response")
        }
    }

    func startSession() async throws {
        await MainActor.run {
            model.phase = .starting
        }
        // make sure the settings were configured.  otherwise they will get vague errors and not realize what needs done
        guard isServerUrlSet() else {
            throw logger.logAndGetError("Server url has not been set yet.  Please set it in the Settings for the app.")
        }
        
        let response = try await executeRequest(of: Requests_GetModelOutput.self, method: "PUT", path: "sessions")
        
        guard !response.sessionID.isEmpty else {
            throw logger.logAndGetError("No session ID passed from server")
        }
        
        try loadOverlay(response.model)
        sessionId = response.sessionID
        await MainActor.run {
            model.phase = .aligning
        }
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

        if sessionId != nil {
            let _ = try await executeRequest(of: Requests_GetModelOutput.self, method: "DELETE", path: "sessions/\(sessionId!)")
        }
        
        await MainActor.run {
            model.phase = .done
        }

        // todo: notify the server so it can close the session
    }
    
    /// Begins the ongoing process of tracking the position of the bone.  This makes a single pose request to the server, so this is a long-running operation
    func startTracking() async throws {
        await MainActor.run {
            model.phase = .initializingTracking
        }

        try await trackOnce()

        await MainActor.run {
            model.phase = .tracking
        }

        // starts the ongoing tracking
        self.trackingTask = createTrackingTask()
    }
    
    func createTrackingTask() -> Task<(), Never> {
        let trackingSessionId = sessionId
        
        return Task(priority: .medium) {
            while (self.sessionId == trackingSessionId) {
                guard !Task.isCancelled else {
                    self.logger.info("Tracking task ended.")
                    return
                }
                guard Settings.shared.continuouslyTrack || trackingCount == 0 else {
                    self.logger.info("Stopped tracking after first one due to continuously_track being disabled")
                    return
                }
                do {
                    try await trackOnce()
                } catch {
                    logger.error("Tracking failed: \(error.localizedDescription)")
                    await model.setError(errorTitle: "Tracking failed", errorMessage: error.localizedDescription)
                    // TODO: user should be able to retry, in which case this should not return
                    return
                }
            }
        }
    }

    /// Makes a request to the server and updates the overlay position accordingly
    func trackOnce() async throws {
        guard let frame = await self.sceneView?.session.currentFrame else {
            throw logger.logAndGetError("Could not get current AR frame")
        }
        guard let sessionId = self.sessionId else {
            throw logger.logAndGetError("No session ID present.")
        }
        
        let request = try makeTrackingRequest(sessionId: sessionId, frame: frame)
        let requestData = try request.serializedData()
        trackingCount += 1

        #if DEBUG
            try saveTrackingRequest(request)
        #endif
        
        let response = try await executeRequest(of: Requests_GetPositionOutput.self, method: "POST", path: "sessions/\(sessionId)", body: requestData)
        guard !Task.isCancelled else {
            return
        }
        logger.info("Tracking update \(trackingCount) Frame timestamp: \(frame.timestamp) Transform: \(response.transform)")

        guard let resultTransform = createSim4Float4x4(response.transform)?.transpose else {
            throw logger.logAndGetError("Result transform was invalid")
        }
        guard let overlayNode = overlayNode else {
            throw logger.logAndGetError("Overlay was not present")
        }
        
        let position = SCNVector3(resultTransform.columns.3.x, resultTransform.columns.3.y, resultTransform.columns.3.z)
        let orientationVector = simd_quaternion(resultTransform).vector
        let orientation = SCNQuaternion(orientationVector.x, orientationVector.y, orientationVector.z, orientationVector.w)
        if self.pinGuideNode == nil {
            self.pinGuideNode = createAxis()
        }
        let axis = self.pinGuideNode!

        await MainActor.run {
            guard !Task.isCancelled else {
                return
            }
            logger.info("Fixing overlay at position \(position) and orientation \(orientation)")
            overlayNode.position = position
            overlayNode.orientation = orientation
            overlayNode.opacity = 0.8 // show more of it

            if axis.parent == nil {
                axis.position = SCNVector3(x: 0.06, y: 0, z: 0)
                axis.eulerAngles = SCNVector3(x: Float.pi/2, y: 0, z: 0)
                
                // WIP: add the axis for the first pin
                overlayNode.addChildNode(axis)
            }
        }
    }

}

// Helper function to create a combined rotation and translation matrix
func simd_make_float4x4(translation: SIMD3<Float>, rotation: (pitch: Float, yaw: Float, roll: Float)) -> matrix_float4x4 {
    let rotationX = makeRotationMatrix(axis: SIMD3<Float>(1, 0, 0), angle: rotation.pitch)
    let rotationY = makeRotationMatrix(axis: SIMD3<Float>(0, 1, 0), angle: rotation.yaw)
    let rotationZ = makeRotationMatrix(axis: SIMD3<Float>(0, 0, 1), angle: rotation.roll)

    let rotationMatrix = simd_mul(simd_mul(rotationX, rotationY), rotationZ)

    var translationMatrix = matrix_identity_float4x4
    translationMatrix.columns.3 = SIMD4<Float>(translation.x, translation.y, translation.z, 1)

    return simd_mul(rotationMatrix, translationMatrix)
}

func createSim4Float4x4(_ array: [Float]) -> simd_float4x4? {
    guard array.count == 16 else {
        return nil
    }
    
    // Create simd_float4 vectors for each row
    let row0 = simd_float4(array[0], array[1], array[2], array[3])
    let row1 = simd_float4(array[4], array[5], array[6], array[7])
    let row2 = simd_float4(array[8], array[9], array[10], array[11])
    let row3 = simd_float4(array[12], array[13], array[14], array[15])
    
    // Construct the simd_float4x4 matrix from the rows
    let matrix = simd_float4x4(row0, row1, row2, row3)
    return matrix
}


// Create a rotation matrix around an axis by an angle to avoid conflict
func makeRotationMatrix(axis: SIMD3<Float>, angle: Float) -> matrix_float4x4 {
    let c = cos(angle)
    let s = sin(angle)

    let column0 = SIMD4<Float>(c + pow(axis.x, 2) * (1 - c), axis.x * axis.y * (1 - c) - axis.z * s, axis.x * axis.z * (1 - c) + axis.y * s, 0)
    let column1 = SIMD4<Float>(axis.y * axis.x * (1 - c) + axis.z * s, c + pow(axis.y, 2) * (1 - c), axis.y * axis.z * (1 - c) - axis.x * s, 0)
    let column2 = SIMD4<Float>(axis.z * axis.x * (1 - c) - axis.y * s, axis.z * axis.y * (1 - c) + axis.x * s, c + pow(axis.z, 2) * (1 - c), 0)
    let column3 = SIMD4<Float>(0, 0, 0, 1)

    return matrix_float4x4(columns: (column0, column1, column2, column3))
}

func loadMDLAsset(_ data: Data) throws -> MDLAsset {
    // Create a temporary URL to save the file
    let temporaryDirectoryURL = FileManager.default.temporaryDirectory
    let temporaryFileURL = temporaryDirectoryURL.appendingPathComponent("\(UUID().uuidString).usdz") // extension is important.  otherwise the overlay won't show
    try data.write(to: temporaryFileURL, options: [.atomic])

    print("Loading model asset of \(data.count) bytes from \(temporaryFileURL.absoluteString)")
    let asset = MDLAsset(url: temporaryFileURL)
    // delete the file cuz we don't need it
    try FileManager.default.removeItem(at: temporaryFileURL)
    return asset
}
