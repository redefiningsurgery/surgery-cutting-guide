import SwiftUI
import SceneKit
import SceneKit.ModelIO
import ARKit
import Combine
import SwiftProtobuf

class SurgeryController: NSObject {
    enum OverlayPosition {
        case frontOfCamera
        case fixed
    }

    let model: SurgeryModel
    private var logger = RedefineLogger("SurgeryController")
    private var sceneView: ARSCNView? = nil
    private var scene: SCNScene? = nil
    private var overlayNode: SCNNode?
    private var overlayPosition: OverlayPosition = .frontOfCamera
    private var showOverlaySubscription: AnyCancellable?
    private var sessionId: String? = nil

    override init() {
        model = SurgeryModel()

        super.init()

        model.delegate = self
    }
    
    func pause() {
        self.sceneView?.session.pause()
        logger.info("Stopped AR session")
    }
    
    private var adjustedWorldOrigin = false
    
    private func startArSession() throws {
        guard let sceneView = sceneView else {
            throw logger.logAndGetError("No sceneView.  Cannot start ARSession")
        }
        adjustedWorldOrigin = false
        let configuration = ARWorldTrackingConfiguration()
        configuration.frameSemantics.insert(.sceneDepth)
        // https://developer.apple.com/documentation/arkit/arkit_in_ios/content_anchors/scanning_and_detecting_3d_objects
        configuration.planeDetection = .horizontal
        configuration.isAutoFocusEnabled = true

        sceneView.session.delegate = self
        sceneView.session.run(configuration, options: [.resetTracking])
        logger.info("Started AR session")
    }

    func addOverlayModel(_ data: Data) throws {
        guard overlayNode == nil, let scene = scene else {
            throw logger.logAndGetError("addOverlayModel called but overlayModel already existed or scene was missing")
        }

        let modelAsset = try loadMDLAsset(data)
        modelAsset.loadTextures()
        let modelObject = modelAsset.object(at: 0)

        // this causes the UI to freeze.  but I tried to put it in a background task and that didn't help. we'll have to handle this later
        let modelNode = SCNNode(mdlObject: modelObject)
        modelNode.scaleToWidth(20)
        // make it translucent
        modelNode.opacity = 0.5
        // rotate the model up
        // modelNode.rotate(x: 90, y: 90, z: 0)

        overlayNode = modelNode // Store the reference
        overlayPosition = .frontOfCamera
        updateOverlayModelPosition()
        scene.rootNode.addChildNode(modelNode)
        logger.info("Added model to scene")
    }

    func updateOverlayModelPosition() {
        guard let currentFrame = sceneView?.session.currentFrame else {
            logger.warning("Could not get current ARFrame to update position of Overlay")
            return
        }
        guard let overlayModel = overlayNode else {
            logger.warning("No leading Overlay to update position for")
            return
        }
        guard overlayPosition == .frontOfCamera else {
            logger.warning("updateOverlayModelPosition called but it should not be floating in front of the camera")
            return
        }
        
        // Use the camera's transform to get its current orientation and position
        let transform = currentFrame.camera.transform
        let cameraPosition = SCNVector3(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
        
        // Calculate the forward vector from the camera transform
        let forward = SCNVector3(-transform.columns.2.x, -transform.columns.2.y, -transform.columns.2.z)
        let adjustedForward = forward.normalized() * 0.5 // Adjust to be 0.5 meters in front
        
        overlayModel.position =  adjustedForward + cameraPosition

        let cameraTransform = currentFrame.camera.transform
        let simdQuaternion = simd_quaternion(cameraTransform)

        // Convert simd_quatf (quaternion) to SCNQuaternion (or SCNVector4)
        let scnQuaternion = SCNQuaternion(simdQuaternion.vector.x, simdQuaternion.vector.y, simdQuaternion.vector.z, simdQuaternion.vector.w)

        // Assign the converted quaternion to your node
        overlayModel.orientation = scnQuaternion
    }
    
    func removeOverlayModel() {
        overlayNode?.removeFromParentNode()
        overlayNode = nil
    }
}

extension SurgeryController: ARSCNViewDelegate {
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        DispatchQueue.main.async {
            if self.overlayNode != nil && self.overlayPosition == .frontOfCamera {
                self.updateOverlayModelPosition()
            }
        }
    }
}

extension SurgeryController: ARSessionDelegate {
    /// Called every time the ARFrame is updated
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // frame.sceneDepth?.depthMap
        
        // if this is the first frame in the session, adjust the world origin so the center is slightly in front of the phone
        if !adjustedWorldOrigin {
            adjustedWorldOrigin = true
            
            DispatchQueue.main.async {
                // Get the current orientation of the device in terms of camera transform
                let currentTransform = frame.camera.transform

                // Define the desired shift and rotation
                let desiredShiftAndRotation = simd_make_float4x4(translation: [-0.0, -0.0, -0.5], rotation: (pitch: 0, yaw: 0, roll: 0))

                // Combine the current orientation with the desired transformation
                let combinedTransform = simd_mul(currentTransform, desiredShiftAndRotation)

                // Apply the combined transformation as the new world origin
                session.setWorldOrigin(relativeTransform: combinedTransform)
                self.logger.trace("Adjusted world origin")
            }
        }
    }
}


extension SurgeryController: SurgeryModelDelegate {
    
    /// Creates the ARSCNView used to show the camera and added scenery
    func getARView() throws -> ARSCNView {
        if let sceneView = self.sceneView {
            logger.warning("sceneView was previously created.  Returning that.")
            return sceneView
        }
        let sceneView = ARSCNView()
        sceneView.automaticallyUpdatesLighting = true
        sceneView.debugOptions = [
            .showWorldOrigin,
            // show the feature points that ARKit uses for tracking https://developer.apple.com/documentation/arkit/arframe/2887449-rawfeaturepoints
            .showFeaturePoints,
        ]
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
        let response = try await executeRequest(of: Requests_GetModelOutput.self, method: "PUT", path: "sessions")
        
        guard !response.sessionID.isEmpty else {
            throw logger.logAndGetError("No session ID passed from server")
        }
        
        try addOverlayModel(response.model)
        sessionId = response.sessionID
    }
    
    func stopSession() async throws {
        removeOverlayModel()
        sessionId = nil
        // todo: notify the server so it can close the session
    }
    
    func saveFrame() async throws {
        guard let frame = await self.sceneView?.session.currentFrame else {
            throw logger.logAndGetError("Could not get current AR frame")
        }
        guard let sessionId = self.sessionId else {
            throw logger.logAndGetError("No session ID present.")
        }
        
        #if DEBUG
            let frameDirectory = try saveArFrame(frame)
            logger.info("Saved frame to \(frameDirectory.absoluteString)")
        #endif
        
        let request = try makeTrackingRequest(sessionId: sessionId, frame: frame)
        let response = try await executeRequest(of: Requests_GetPositionOutput.self, method: "POST", path: "sessions/\(sessionId)", body: request)
        
        logger.info("Transform: \(response.transform)")

        guard let resultTransform = createSim4Float4x4(response.transform)?.transpose else {
            throw logger.logAndGetError("Result transform was invalid")
        }
        guard let overlayNode = overlayNode else {
            throw logger.logAndGetError("Overlay was not present")
        }
        
        overlayPosition = .fixed
        let position = SCNVector3(resultTransform.columns.3.x, resultTransform.columns.3.y, resultTransform.columns.3.z)
        let orientationVector = simd_quaternion(resultTransform).vector
        let orientation = SCNQuaternion(orientationVector.x, orientationVector.y, orientationVector.z, orientationVector.w)
        await MainActor.run {
            logger.info("Fixing overlay at position \(position) and orientation \(orientation)")
            overlayNode.position = position
            overlayNode.orientation = orientation
            overlayNode.opacity = 0.8 // show more of it
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
