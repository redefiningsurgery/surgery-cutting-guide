//
//  SurgeryModel.swift
//  RedefineGuide
//
//  Created by Stephen Potter on 4/8/24.
//

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
    
    func addSomething() {
        do {
            try delegate?.addSomething()
        } catch {
            logger.error("Error adding something: \(error.localizedDescription)")
        }
    }
    
}


protocol SurgeryModelDelegate: AnyObject {
    func getARView() -> ARSCNView
    func addSomething() throws
}
