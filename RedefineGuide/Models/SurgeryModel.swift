import Foundation
import ARKit

class SurgeryModel: NSObject, ObservableObject {
    
    var delegate: SurgeryModelDelegate? = nil
    private var logger = RedefineLogger("ARViewController")

    func getARView() -> ARSCNView {
        if delegate == nil {
            logger.warning("SurgeryModel delegate is nil")
        }
        return delegate?.getARView() ?? ARSCNView()
    }
    
    func onTap(point: CGPoint) {
        do {
            try delegate?.addSomething(point: point)
        } catch {
            logger.error("Error adding something: \(error.localizedDescription)")
        }
    }
    
}


protocol SurgeryModelDelegate: AnyObject {
    func getARView() -> ARSCNView
    func addSomething(point: CGPoint) throws
}
