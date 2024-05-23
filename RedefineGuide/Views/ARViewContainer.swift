import SwiftUI
import RealityKit
import ARKit

/// Contains the ARView that the ARSession and RealityKit is drawn on
struct ARViewContainer: UIViewRepresentable {
    @ObservedObject var model: SurgeryModel

    func makeUIView(context: Context) -> ARView {
        return model.getARView()
    }

    func updateUIView(_ uiView: ARView, context: Context) {}
}


