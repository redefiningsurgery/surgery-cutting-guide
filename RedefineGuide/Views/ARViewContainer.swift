import SwiftUI
import SceneKit
import ARKit

/// Contains the ARSCNView that the ARSession and SceneKit is drawn on
struct ARViewContainer: UIViewRepresentable {
    @ObservedObject var model: SurgeryModel

    func makeUIView(context: Context) -> ARSCNView {
        return model.getARView()
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {}
}

