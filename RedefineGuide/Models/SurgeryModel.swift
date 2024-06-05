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
    @Published var errorVisible: Bool = false
    /// Only useful if errorExists is true.  Contains a short message like "Error starting recording", which can be used as a title for alerts
    @Published private(set) var errorTitle: String = ""
    /// Only useful if errorExists is true.  Contains some details of the error message like: "Device is in low power mode.  Turn off low power mode to re-enable recording"
    @Published private(set) var errorMessage: String = ""

    @Published var axis1X: Float = 0.038
    @Published var axis1Y: Float = -0.002
    @Published var axis1Z: Float = 0.073

    @Published var axisXAngle: Float = 90
    @Published var axisYAngle: Float = 13
    @Published var axisZAngle: Float = 0

    @Published var axis2X: Float = 0.01
    @Published var axis2Y: Float = -0.002
    @Published var axis2Z: Float = 0.079

    var delegate: SurgeryModelDelegate? = nil
    private var logger = RedefineLogger("SurgeryModel")

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

    // you can probably get rid of this now
    func saveSnapshot() async {
        guard let delegate = delegate else {
            logger.warning("saveSnapshot did nothing because delegate is nil")
            return
        }
        do {
            try await delegate.saveSnapshot()
        } catch {
            logger.error("saveSnapshot: \(error.localizedDescription)")
        }
    }
}


protocol SurgeryModelDelegate: AnyObject {
    func getARView() throws -> ARSCNView
    func resetWorldOrigin() throws
    func startTracking() async throws
    func startSession() async throws
    func stopSession() async throws
    func saveSnapshot() async throws
}
