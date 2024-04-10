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
    
    func onTap(point: CGPoint) {
        do {
            try delegate?.addSomething(point: point)
        } catch {
            logger.error("Error adding something: \(error.localizedDescription)")
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
    
}


protocol SurgeryModelDelegate: AnyObject {
    func getARView() throws -> ARSCNView
    func resetWorldOrigin() throws
    func addSomething(point: CGPoint) throws
}
