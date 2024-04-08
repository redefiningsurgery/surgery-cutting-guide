import Foundation
import ARKit

class AppInitializer {
    let model: AppInitializationModel
    private var logger = RedefineLogger("AppInitializer")

    @MainActor
    init() {
        model = AppInitializationModel()
    }

    func start() async {
        guard ARWorldTrackingConfiguration.isSupported && ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) && ARWorldTrackingConfiguration.supportsFrameSemantics(.bodyDetection) else {
            logger.warning("Device does not have necessary AR capabilities")
            await MainActor.run {
                model.status = .failed("This device does not have the required AR capabilities.")
            }
            return
        }
        
        guard await requestCameraPermission() else {
            await MainActor.run {
                model.status = .failed("This app requires camera access.")
            }
            return
        }

        await MainActor.run {
            model.status = .initialized
        }
    }
    
    func requestCameraPermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .video) { granted in
                continuation.resume(returning: granted)
            }
        }
    }

}
