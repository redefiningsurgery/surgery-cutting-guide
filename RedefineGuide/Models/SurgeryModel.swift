import Foundation
import ARKit

class SurgeryModel: NSObject, ObservableObject {

    @Published var startedSession = false

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

    func startSession() async {
        guard let delegate = delegate else {
            logger.warning("startSession did nothing because delegate is nil")
            return
        }
        do {
            try await delegate.startSession()
            await MainActor.run {
                startedSession = true
            }
        } catch {
            logger.error("startSession: \(error.localizedDescription)")
        }
    }
    
    func stopSession() async {
        guard let delegate = delegate else {
            logger.warning("stopSession did nothing because delegate is nil")
            return
        }
        do {
            try await delegate.stopSession()
            await MainActor.run {
                startedSession = false
            }
        } catch {
            logger.error("stopSession: \(error.localizedDescription)")
        }
    }
    
    func startTracking() async {
        guard let delegate = delegate else {
            logger.warning("saveFrame did nothing because delegate is nil")
            return
        }
        do {
            try await delegate.startTracking()
        } catch {
            logger.error("saveFrame: \(error.localizedDescription)")
        }
    }
    
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
