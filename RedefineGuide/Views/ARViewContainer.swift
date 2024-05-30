import SwiftUI
import SceneKit
import ARKit

/// Contains the ARSCNView that the ARSession and SceneKit is drawn on
/// If there is an overlayBounds set by the model, everything except the overlayBounds is blurred out.  This is for the alignment phase
struct ARViewContainer: UIViewRepresentable {
    @ObservedObject var model: SurgeryModel
    
    func makeUIView(context: Context) -> ARSCNView {
        return model.getARView()
    }
    
    func updateUIView(_ uiView: ARSCNView, context: Context) {
    }
}
