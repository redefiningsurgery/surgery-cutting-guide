import SwiftUI
import SceneKit
import SceneKit.ModelIO
import ARKit
import Combine

class SurgeryController: NSObject {

    let model: SurgeryModel
    private var logger = RedefineLogger("SurgeryController")
    private var sceneView: ARSCNView? = nil
    private var scene: SCNScene? = nil
    private var overlayNode: SCNNode?
    private var showOverlaySubscription: AnyCancellable?

    override init() {
        model = SurgeryModel()

        super.init()

        model.delegate = self
        showOverlaySubscription = model.$showOverlay
            .sink { [weak self] newValue in
                self?.handleShowOverlayChanged(newValue)
            }
    }
    
    private func handleShowOverlayChanged(_ show: Bool) {
        guard sceneView != nil else {
            return
        }
        if show {
            addOverlayModel()
        } else {
            removeOverlayModel()
        }
    }
    
    func pause() {
        self.sceneView?.session.pause()
        logger.info("Stopped AR session")
    }
    
    private var adjustedWorldOrigin = false
    
    private func startSession() throws {
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

    /// Loads the given usdz file into a SCNNode.  Note that this should be processed on a background thread, as it is resource intensive and would cause the UI thread to pause
    private func loadModel(_ name: String) throws -> SCNNode {
        guard let modelURL = Bundle.main.url(forResource: name, withExtension: "usdz") else {
            throw logger.logAndGetError("Could not find model file for \(name)")
        }
        let modelAsset = MDLAsset(url: modelURL)
        modelAsset.loadTextures()
        let modelObject = modelAsset.object(at: 0)
        return SCNNode(mdlObject: modelObject)
    }
    
    func addOverlayModel() {
        guard overlayNode == nil, let scene = scene else {
            logger.error("addOverlayModel called but overlayModel already existed or scene was missing")
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let modelNode = try self.loadModel("bone")
                DispatchQueue.main.async {
                    modelNode.scaleToWidth(15)
                    modelNode.opacity = 0.5
                    modelNode.rotate(x: 0, y: 0, z: 0)

                    // Set up materials
                    let material = SCNMaterial()
                    material.lightingModel = .physicallyBased
                    material.metalness.contents = 1.0
                    material.roughness.contents = 0.0
                    modelNode.geometry?.firstMaterial = material

                    // Set up scene lighting
                    let lightNode = SCNNode()
                    lightNode.light = SCNLight()
                    lightNode.light?.type = .omni
                    lightNode.position = SCNVector3(x: 10, y: 10, z: 10)
                    scene.rootNode.addChildNode(lightNode)

                    let ambientLightNode = SCNNode()
                    ambientLightNode.light = SCNLight()
                    ambientLightNode.light?.type = .ambient
                    ambientLightNode.light?.color = UIColor.darkGray
                    scene.rootNode.addChildNode(ambientLightNode)

                    self.overlayNode = modelNode // Store the reference
                    self.updateOverlayModelPosition()
                    scene.rootNode.addChildNode(modelNode)
                    self.logger.info("Added model to scene")
                }
            } catch {
                DispatchQueue.main.async {
                    self.logger.error("Could not add leading model: \(error.localizedDescription)")
                }
            }
        }
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
        
//        // *** Fixed cad model relative to the camera
//        let cameraTransform = currentFrame.camera.transform
//        let cameraPosition = SCNVector3(cameraTransform.columns.3.x, cameraTransform.columns.3.y, cameraTransform.columns.3.z)
//        let forward = SCNVector3(-cameraTransform.columns.2.x, -cameraTransform.columns.2.y, -cameraTransform.columns.2.z)
//        let adjustedForward = forward.normalized() * 0.9 // Adjust to be 0.5 meters in front
//        overlayModel.position =  adjustedForward + cameraPosition
//
//        let cameraQuaternion = simd_quaternion(cameraTransform)
//        let scnQuaternion = SCNQuaternion(cameraQuaternion.vector.x, cameraQuaternion.vector.y, cameraQuaternion.vector.z, cameraQuaternion.vector.w)
//        overlayModel.orientation = scnQuaternion
//        // *** Fixed cad model relative to the camera
        
        // *** Fixed CAD model relative to world
        let fixedWorldPosition = SCNVector3(x: 0.0, y: 0.0, z: 0.0)
        let fixedWorldOrientation = SCNQuaternion(x: 0.0, y: 1.0, z: 0.0, w: 1.0)

        overlayModel.position = fixedWorldPosition
        overlayModel.orientation = fixedWorldOrientation
        // *** Fixed CAD model relative to world
        
        
    }
    
    func removeOverlayModel() {
        overlayNode?.removeFromParentNode()
        overlayNode = nil
    }
}

extension SurgeryController: ARSCNViewDelegate {
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        DispatchQueue.main.async {
            if self.overlayNode != nil {
                self.updateOverlayModelPosition()
            }
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        logger.trace("ARAnchor added: \(type(of: anchor))")
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
                let cameraTransform = frame.camera.transform
                let capturingTransform = simd_float4x4([
                        simd_float4(0.008679075, -0.99172944, 0.1280538, 0.0),
                        simd_float4(0.9999623, 0.008607603, -0.001111559, 0.0),
                        simd_float4(1.2638304e-07, 0.12805861, 0.9917668, 0.0),
                        simd_float4(0.0, 0.0, 0.0, 1.0)])
                let inverseCapturingTransform = simd_inverse(capturingTransform)
                let relativeTransform = simd_mul(inverseCapturingTransform, cameraTransform)
                
                // Define constants for translation and rotation
                let dx: Float = 0.0  // meters to the right
                let dy: Float = 0.0  // meters upward
                let dz: Float = -1.0  // meters forward
                let rotationAngle: Float = 0 * Float.pi / 4  // 45 degrees in radians

                // Translation matrix
                let translationMatrix = simd_float4x4(
                    SIMD4<Float>(1, 0, 0, 0),
                    SIMD4<Float>(0, 1, 0, 0),
                    SIMD4<Float>(0, 0, 1, 0),
                    SIMD4<Float>(dx, dy, dz, 1))
                let rotationMatrix = simd_float4x4(
                    SIMD4<Float>(cos(rotationAngle), 0, -sin(rotationAngle), 0),
                    SIMD4<Float>(0, 1, 0, 0),
                    SIMD4<Float>(sin(rotationAngle), 0, cos(rotationAngle), 0),
                    SIMD4<Float>(0, 0, 0, 1))
                let desiredShiftAndRotation = simd_mul(translationMatrix, rotationMatrix)
                let combinedTransform = simd_mul(cameraTransform, desiredShiftAndRotation)
                
                session.setWorldOrigin(relativeTransform: combinedTransform)
                self.logger.trace("Adjusted world origin")
                let cam = frame.camera.transform
                print("Camera Transform: \(cam)")
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
        try startSession()
     
        if model.showOverlay {
            addOverlayModel()
        }
        
        return sceneView
    }
    
    func resetWorldOrigin() throws {
        pause()
        try startSession()
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


