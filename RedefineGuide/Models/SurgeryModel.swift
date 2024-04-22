import Foundation
import ARKit

class SurgeryModel: NSObject, ObservableObject {

    @Published var showOverlay = false

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

    func saveFrame() async {
        guard let delegate = delegate else {
            logger.warning("saveFrame did nothing because delegate is nil")
            return
        }
        do {
            try await delegate.saveFrame()
        } catch {
            logger.error("Error saveFrame: \(error.localizedDescription)")
        }
    }
}


protocol SurgeryModelDelegate: AnyObject {
    func getARView() throws -> ARSCNView
    func resetWorldOrigin() throws
    func saveFrame() async throws
}
