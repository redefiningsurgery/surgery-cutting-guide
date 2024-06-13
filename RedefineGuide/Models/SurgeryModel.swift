import Foundation
import ARKit

enum SurgeryPhase {
    case notStarted
    case starting
    case aligning
    case initializingTracking
    case tracking
    case done
}


class SurgeryModel: NSObject, ObservableObject {
    
    @Published @MainActor var phase: SurgeryPhase = .notStarted
    
    /// Indicates whether the recorder has encountered an error and it has not been dismissed by the user
    @Published @MainActor var errorVisible: Bool = false
    /// Only useful if errorExists is true.  Contains a short message like "Error starting recording", which can be used as a title for alerts
    @Published @MainActor private(set) var errorTitle: String = ""
    /// Only useful if errorExists is true.  Contains some details of the error message like: "Device is in low power mode.  Turn off low power mode to re-enable recording"
    @Published @MainActor private(set) var errorMessage: String = ""

    // Note: tracking needs to be restarted for these values to be reflected
    @Published @MainActor var axisRadius: Float = 0.001
    @Published @MainActor var axisLength: Float = 0.07

    // Axes properties that can be measured by the adjustment form, which can be turned on in Settings
    @Published @MainActor var axis1X: Float = 0.038
    @Published @MainActor var axis1Y: Float = -0.002
    @Published @MainActor var axis1Z: Float = 0.060

    @Published @MainActor var axisXAngle: Float = 90
    @Published @MainActor var axisYAngle: Float = 13
    @Published @MainActor var axisZAngle: Float = 0

    @Published @MainActor var axis2X: Float = 0.01
    @Published @MainActor var axis2Y: Float = -0.002
    @Published @MainActor var axis2Z: Float = 0.066

    var delegate: SurgeryModelDelegate? = nil
    private var logger = RedefineLogger("SurgeryModel")

    @MainActor
    func getARView() -> ARSCNView {
        guard let delegate = delegate else {
            logger.warning("Cannot get ARView because delegate is nil")
            return ARSCNView()
        }
        do {
            return try delegate.getARView()
        } catch {
            logger.error("Error getting ARView: \(error.localizedDescription)")
            return ARSCNView()
        }
    }

    func resetWorldOrigin() {
        guard let delegate = delegate else {
            logger.warning("resetWorldOrigin did nothing because delegate is nil")
            return
        }
        do {
            try delegate.resetWorldOrigin()
        } catch {
            logger.error("Error resetWorldOrigin: \(error.localizedDescription)")
        }
    }

    @MainActor
    func setError(errorTitle: String, errorMessage: String) {
        self.errorVisible = true
        self.errorTitle = errorTitle
        self.errorMessage = errorMessage
    }

    @MainActor
    func startSession() {
        guard let delegate = delegate else {
            logger.warning("startSession did nothing because delegate is nil")
            phase = .starting
            return
        }
        Task(priority: .high) {
            do {
                try await delegate.startSession()
            } catch {
                logger.error("startSession: \(error.localizedDescription)")
                setError(errorTitle: "Could not start procedure", errorMessage: error.localizedDescription)
            }
        }
    }

    @MainActor
    func stopSession() {
        guard let delegate = delegate else {
            logger.warning("stopSession did nothing because delegate is nil")
            return
        }
        Task(priority: .high) {
            do {
                try await delegate.stopSession()
            } catch {
                logger.error("stopSession: \(error.localizedDescription)")
                setError(errorTitle: "Could not stop procedure", errorMessage: error.localizedDescription)
            }
        }
    }

    @MainActor
    func startTracking() {
        guard let delegate = delegate else {
            logger.warning("startTracking did nothing because delegate is nil")
            return
        }
        Task(priority: .high) {
            do {
                try await delegate.startTracking()
            } catch {
                logger.error("startTracking: \(error.localizedDescription)")
                setError(errorTitle: "Could not start tracking", errorMessage: error.localizedDescription)
            }
        }
    }
    
    @MainActor
    func exportScene() async {
        guard let delegate = delegate else {
            logger.warning("exportScene did nothing because delegate is nil")
            return
        }
        Task(priority: .high) {
            do {
                try await delegate.exportScene()
            } catch {
                logger.error("exportScene: \(error.localizedDescription)")
                setError(errorTitle: "Could not export scene", errorMessage: error.localizedDescription)
            }
        }
    }
}


protocol SurgeryModelDelegate: AnyObject {
    func getARView() throws -> ARSCNView
    func resetWorldOrigin() throws
    func startTracking() async throws
    func startSession() async throws
    func stopSession() async throws
    func exportScene() async throws
}
