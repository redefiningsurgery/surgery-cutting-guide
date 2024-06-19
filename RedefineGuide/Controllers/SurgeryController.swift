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
    private var isArSessionRunning = false
    
    @MainActor
    override init() {
        model = SurgeryModel()

        super.init()

        model.delegate = self

        subscribeToModelChanges()
    }

    /// Sets up observers to handle changes in the model and adapt accordingly
    @MainActor
    private func subscribeToModelChanges() {
        Settings.shared.$showARDebugging
            .sink { [weak self] _ in
                if let self = self, let sceneView = self.sceneView {
                    self.updateSceneViewDebugOptions(sceneView)
                }
            }
            .store(in: &cancellables)
        Settings.shared.$alignOverlayWithCamera
            .sink { [weak self] _ in
                if let self = self, let sceneView = self.sceneView {
                    try? self.restartArSession(sceneView)
                }
            }
            .store(in: &cancellables)
        Publishers.Merge6(model.$axis1X, model.$axis1Y, model.$axis1Z, model.$axis2X, model.$axis2Y, model.$axis2Z)
            .receive(on: DispatchQueue.main) // must do this or else changes will be "off by one" when you change values in the UI
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
        model.$overlayOffset
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                if let self = self, self.updateOnModelPositionChanges, let overlayNode = self.overlayNode {
                    self.updateOverlayPosition(overlayNode: overlayNode)
                }
            }
            .store(in: &cancellables)
    }
    
    private func startArSession(_ sceneView: ARSCNView) throws {
        guard !isArSessionRunning else {
            logger.warning("Cannot start ARSession because it's already running")
            return
        }
        let configuration = ARWorldTrackingConfiguration()
        configuration.frameSemantics.insert(.sceneDepth)
        configuration.frameSemantics.insert(.smoothedSceneDepth)
        configuration.planeDetection = [] // when this was set, the overlay was floating around a lot.  removing plane detection helped significantly: https://stackoverflow.com/questions/45020192/how-to-keep-arkit-scnnode-in-place
        configuration.isAutoFocusEnabled = true // super critical because the bone is close up and without this it would be totally out of focus
        if Settings.shared.alignOverlayWithCamera {
            configuration.worldAlignment = .camera // setting this makes it super stable but when you move the camera, the overlay moves as well.  but this is interesting and basically eliminiates the drift problem
        }
        sceneView.session.delegate = self
        sceneView.session.run(configuration, options: [.resetTracking])
        logger.info("Started AR session")
        isArSessionRunning = true
    }

    func stopArSession(_ sceneView: ARSCNView) {
        guard isArSessionRunning else {
            logger.warning("Cannot stop ARSession because either there is no sceneView or the session is not running")
            return
        }
        sceneView.session.pause()
        isArSessionRunning = false
        logger.info("Stopped AR session")
    }


    func loadOverlay(_ data: Data) throws -> SCNNode {
        let modelNode = try loadModelNode(data)
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
            // todo: this results in some god awful long messages.  maybe just log the details and show a summary
            throw logger.logAndGetError(errorDetail)
        }

        do {
            let output = try of.init(serializedData: data)
            return output
        } catch {
            throw logger.logAndGetError("Failed to deserialize response")
        }
    }

}

extension SurgeryController: ARSCNViewDelegate {
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {

    }
    
    func renderer(_ renderer: any SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        logger.info("Added node: \(node.name ?? "N/A") \(type(of: node)) to anchor: \(anchor.name ?? "N/A") \(type(of: anchor))")
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

    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        self.logger.info("Tracking state changed to \(camera.trackingState)")
        DispatchQueue.main.async {
            self.model.isArTrackingNormal = camera.trackingState == .normal
        }
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
        
        self.sceneView = sceneView
        logger.info("Created AR scene view")
        
        updateSceneViewDebugOptions(sceneView)
        try startArSession(sceneView)
        
        return sceneView
    }
    
    func updateSceneViewDebugOptions(_ sceneView: ARSCNView) {
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
    
    func restartArSession(_ sceneView: ARSCNView) throws {
        stopArSession(sceneView)
        try startArSession(sceneView)
    }

    func startSession() async throws {
        await MainActor.run {
            model.phase = .starting
        }
        
        if let sceneView = sceneView, !isArSessionRunning {
            try startArSession(sceneView)
        }

        guard Settings.shared.isServerUrlSet else {
            throw logger.logAndGetError("Server url has not been set yet.  Please set it in the Settings for the app.")
        }
        
        let response = try await executeRequest(of: Requests_GetModelOutput.self, method: "PUT", path: "sessions")
        
        guard !response.sessionID.isEmpty else {
            throw logger.logAndGetError("No session ID passed from server")
        }
        
        let overlayNode = try loadOverlay(response.model)
        self.overlayNode = overlayNode

        sessionId = response.sessionID
        await MainActor.run {
            overlayNode.opacity = CGFloat(model.overlayOpacity)
            model.phase = .aligning
        }
    }
       
    func stopSession() async throws {
        if let trackingTask = trackingTask, !trackingTask.isCancelled {
            trackingTask.cancel()
            await trackingTask.value
        }
        removeOverlayModel()
        let sessionId = sessionId
        self.sessionId = nil
        trackingCount = 0
        
        removeOverlayModel()
        if isArSessionRunning, let sceneView = sceneView {
            stopArSession(sceneView)
        }
        self.sceneView = nil

        if sessionId != nil {
            let _ = try await executeRequest(of: Requests_GetModelOutput.self, method: "DELETE", path: "sessions/\(sessionId!)")
        }
        
        await MainActor.run {
            model.phase = .done
        }
    }
    
    /// Begins the ongoing process of tracking the position of the bone.  This makes a single pose request to the server, so this is a long-running operation
    func startTracking() async throws {
        guard isTrackingStateNormal() else {
            throw logger.logAndGetError("Could not start tracking because the AR system is not normal.  Waiting a moment and retrying may fix it.")
        }
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
        model.overlayTransform = resultTransform
        model.cameraTransform = frame.camera.transform
        guard let overlayNode = overlayNode else {
            throw logger.logAndGetError("Overlay was not present")
        }

        await MainActor.run {
            guard !Task.isCancelled else {
                return
            }
            self.updateOnModelPositionChanges = false
            defer {
                self.updateOnModelPositionChanges = true
            }
            
            updateOverlayPosition(overlayNode: overlayNode)

            if Settings.shared.enableAxes {
                ensureAxes(overlayNode: overlayNode)
            }
        }
    }
    
    @MainActor
    func ensureAxes(overlayNode: SCNNode) {
        guard axis1 == nil && axis2 == nil else {
            return
        }
        
        logger.info("Creating pin guide axes")
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
        let finalTransform = adjustedTransform(originalTransform: model.overlayTransform, cameraTransform: model.cameraTransform, distance: model.overlayOffset) // -0.009
        let position = SCNVector3(finalTransform.columns.3.x, finalTransform.columns.3.y, finalTransform.columns.3.z)
        overlayNode.simdOrientation = simd_quaternion(finalTransform)
        overlayNode.position = position

        logger.info("Placed overlay at position \(position) and orientation \(overlayNode.orientation) with angles \(overlayNode.eulerAngles)")
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
    
    func isTrackingStateNormal() -> Bool {
        guard let sceneView = sceneView, let frame = sceneView.session.currentFrame else {
            return false
        }
        return frame.camera.trackingState == .normal
    }
    
    func exportScene() async throws {
        guard let scene = await self.sceneView?.scene else {
            throw logger.logAndGetError("Could not get scene to export")
        }
        try await scene.export()
    }
}
