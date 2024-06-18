import SwiftUI
import SceneKit
import SceneKit.ModelIO
import ARKit
import Combine
import SwiftProtobuf

let minBoundingBoxSideOfOverlayInMeters: Float = 0.01
let maxBoundingBoxSideOfOverlayInMeters: Float = 0.1

class SurgeryController: NSObject {
    let model: SurgeryModel
    private var logger = RedefineLogger("SurgeryController")
    private var sceneView: ARSCNView? = nil
    private var scene: SCNScene? = nil
    private var overlayNode: SCNNode?
    private var axis1: SCNNode?
    private var axis2: SCNNode?
    private var showOverlaySubscription: AnyCancellable?
    private var sessionId: String? = nil
    private var trackingTask: Task<(), Never>? = nil
    /// The number of times the tracking has been updated.  Each time is a trip to the server
    private var trackingCount: Int = 0
    private var cancellables: Set<AnyCancellable> = []
    private var updateOnModelPositionChanges = true

    @MainActor
    override init() {
        model = SurgeryModel()

        super.init()

        model.delegate = self

        Settings.shared.$showARDebugging
            .sink { [weak self] _ in
                self?.updateSceneViewDebugOptions()
            }
            .store(in: &cancellables)
        
        Publishers.Merge6(model.$axis1X, model.$axis1Y, model.$axis1Z, model.$axis2X, model.$axis2Y, model.$axis2Z)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                if let self = self, self.updateOnModelPositionChanges {
                    self.updateAxisPosition()
                }
            }
            .store(in: &cancellables)
        Publishers.Merge3(model.$axisXAngle, model.$axisYAngle, model.$axisZAngle)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                if let self = self, self.updateOnModelPositionChanges {
                    self.updateAxisPosition()
                }
            }
            .store(in: &cancellables)

        Publishers.Merge3(model.$overlayX, model.$overlayY, model.$overlayZ)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                if let self = self, self.updateOnModelPositionChanges, let overlayNode = self.overlayNode {
                    self.updateOverlayPosition(overlayNode: overlayNode)
                }
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
        configuration.planeDetection = [] // when this was set, the overlay was floating around a lot.  removing plane detection helped a lot
        configuration.isAutoFocusEnabled = true // super critical because the bone is close up and without this it would be totally out of focus
        // configuration.worldAlignment = .camera setting this makes it super stable but when you move the camera, the overlay moves as well.  but this is interesting
        
        sceneView.session.delegate = self
        sceneView.session.run(configuration, options: [.resetTracking])
        logger.info("Started AR session")
    }

    func loadOverlay(_ data: Data) throws -> SCNNode {
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

        guard width <= maxBoundingBoxSideOfOverlayInMeters && width >= minBoundingBoxSideOfOverlayInMeters &&
                height <= maxBoundingBoxSideOfOverlayInMeters && height >= minBoundingBoxSideOfOverlayInMeters &&
                depth <= maxBoundingBoxSideOfOverlayInMeters && depth >= minBoundingBoxSideOfOverlayInMeters else {
            throw logger.logAndGetError("Overlay CAD model was too big.  It needs adjusted.  Dimensions in meters: width=\(width), height=\(height), depth=\(depth)")
        }
        return modelNode
    }
    
    func removeOverlayModel() {
        if let overlayNode = self.overlayNode {
            logger.info("Removed overlay")
            overlayNode.removeFromParentNode()
            self.overlayNode = nil
            self.axis1 = nil
            self.axis2 = nil
        }
    }
}

extension SurgeryController: ARSCNViewDelegate {
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {

    }
}

extension SurgeryController: ARSessionDelegate {

    fileprivate func ensureOverlayIsInScene() {
        guard let overlayNode = self.overlayNode, let sceneView = self.sceneView else {
            return
        }
        if overlayNode.parent == nil {
            self.logger.info("Adding overlay to the scene")
            sceneView.scene.rootNode.addChildNode(overlayNode)
        }
    }

    fileprivate func ensureOverlayIsNotInScene() {
        guard let overlayNode = self.overlayNode else {
            return
        }
        if overlayNode.parent != nil {
            self.logger.info("Removing overlay from the scene")
            overlayNode.removeFromParentNode()
        }
    }

    /// Called every time the ARFrame is updated
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        DispatchQueue.main.async {
            switch self.model.phase {
            case .tracking:
                self.ensureOverlayIsInScene()
            default:
                self.ensureOverlayIsNotInScene()
            }
        }
    }
    
    func session(_ session: ARSession, didChange geoTrackingStatus: ARGeoTrackingStatus
    ) {
        self.logger.info("Tracking status changed")
    }
    
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        self.logger.info("Tracking state changed to \(camera.trackingState)")
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
        sceneView.delegate = self
        
        let scene = SCNScene()
        sceneView.scene = scene
        
        self.scene = scene
        self.sceneView = sceneView
        
        updateSceneViewDebugOptions()
        try startArSession()
        
        return sceneView
    }
    
    func updateSceneViewDebugOptions() {
        guard let sceneView = self.sceneView else {
            return
        }

        if Settings.shared.showARDebugging {
            sceneView.debugOptions = [
                .showWorldOrigin,
                .showBoundingBoxes,
                .showFeaturePoints
            ]
        } else {
            sceneView.debugOptions = []
        }
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
        
        self.overlayNode = try loadOverlay(response.model)
        sessionId = response.sessionID
        await MainActor.run {
            model.phase = .aligning
        }
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
                    guard !Task.isCancelled else {
                        self.logger.info("Tracking task ended during trackOnce")
                        return
                    }
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

        if Settings.shared.saveRequests {
            try saveTrackingRequest(request)
        }

        guard !Task.isCancelled else {
            return
        }
        let response = try await executeRequest(of: Requests_GetPositionOutput.self, method: "POST", path: "sessions/\(sessionId)", body: requestData)
        guard !Task.isCancelled else {
            return
        }
        logger.info("Tracking update \(trackingCount) Frame timestamp: \(frame.timestamp) Transform: \(response.transform)")

        guard let resultTransform = createSim4Float4x4FromRowMajor(response.transform) else {
            throw logger.logAndGetError("Result transform was invalid")
        }
        
        guard let overlayNode = overlayNode else {
            throw logger.logAndGetError("Overlay was not present")
        }

        await MainActor.run {
            guard !Task.isCancelled else {
                return
            }
            self.updateOnModelPositionChanges = false
            model.overlayX = resultTransform.columns.3.x
            model.overlayY = resultTransform.columns.3.y
            model.overlayZ = resultTransform.columns.3.z
            self.updateOnModelPositionChanges = true

            overlayNode.simdOrientation = simd_quaternion(resultTransform)
            overlayNode.opacity = 0.8

            ensureAxises(overlayNode: overlayNode)
            updateOverlayPosition(overlayNode: overlayNode)
        }
    }
    
    @MainActor
    func ensureAxises(overlayNode: SCNNode) {
        guard axis1 == nil && axis2 == nil else {
            return
        }
        
        logger.info("Creating pin guide axises")
        let axis1 = createAxis(radius: model.axisRadius, length: model.axisLength)
        self.axis1 = axis1

        let axis2 = createAxis(radius: model.axisRadius, length: model.axisLength)
        self.axis2 = axis2

        updateAxisPosition()
        overlayNode.addChildNode(axis1)
        overlayNode.addChildNode(axis2)
    }
    
    @MainActor
    func updateOverlayPosition(overlayNode: SCNNode) {
        let position = SCNVector3(model.overlayX, model.overlayY, model.overlayZ)
        overlayNode.position = position
        
        logger.info("Placed overlay at position \(position) and orientation \(overlayNode.orientation) with angles \(overlayNode.eulerAngles)")
        logger.info("Angles: \(overlayNode.eulerAngles)")
    }
    
    @MainActor
    func updateAxisPosition() {
        guard let axis1 = axis1, let axis2 = axis2 else {
            return
        }
        
        axis1.rotate(x: CGFloat(model.axisXAngle), y: CGFloat(model.axisYAngle), z: CGFloat(model.axisZAngle))
        axis1.position = SCNVector3(x: model.axis1X, y: model.axis1Y, z: model.axis1Z)
        logger.info("Axis 1 position: \(axis1.position), angles (\(model.axisXAngle),\(model.axisYAngle),\(model.axisZAngle)): \(axis1.eulerAngles)")

        axis2.rotate(x: CGFloat(model.axisXAngle), y: CGFloat(model.axisYAngle), z: CGFloat(model.axisZAngle))
        axis2.position = SCNVector3(x: model.axis2X, y: model.axis2Y, z: model.axis2Z)
        logger.info("Axis 2 position: \(axis2.position), angles (\(model.axisXAngle),\(model.axisYAngle),\(model.axisZAngle)): \(axis2.eulerAngles)")
    }
    
    func exportScene() async throws {
        guard let scene = self.scene else {
            throw logger.logAndGetError("Could not get scene to export")
        }
        try await scene.export()
    }
}
