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
        updateMask(in: uiView, for: model.getOverlayClipBounds())
    }
    
    private func getBlurEffectView(_ view: UIView) -> UIVisualEffectView? {
        return view.subviews.first(where: { $0 is UIVisualEffectView }) as? UIVisualEffectView
    }

    private func updateMask(in view: UIView, for bounds: CGRect?) {
        if let bounds = bounds {
            if let blurEffectView = getBlurEffectView(view), let maskLayer = blurEffectView.layer.mask as? CAShapeLayer {
                maskLayer.path = createCutoutPath(bounds: bounds, blurEffectView: blurEffectView)
                return
            }
            // Everything to create the blur effect
            let blurEffect = UIBlurEffect(style: .systemThinMaterial)
            let blurEffectView = UIVisualEffectView(effect: blurEffect)
            blurEffectView.frame = view.bounds
            blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            blurEffectView.isUserInteractionEnabled = false // Allows user interaction to pass through to the ARSCNView
            view.addSubview(blurEffectView)
            let maskLayer = CAShapeLayer()
            maskLayer.fillRule = .evenOdd
            maskLayer.path = createCutoutPath(bounds: bounds, blurEffectView: blurEffectView)
            blurEffectView.layer.mask = maskLayer
        } else {
            // Get rid of the blur effect, otherwise things will go wonky
            if let blurEffectView = getBlurEffectView(view) {
                blurEffectView.removeFromSuperview()
            }
        }
    }
    
    /// Creates a path that is used to cut out the blur to show only the overlay during the alignment phase
    private func createCutoutPath(bounds: CGRect, blurEffectView: UIVisualEffectView) -> CGMutablePath {
        let path = CGMutablePath()
        // Add a subpath which is the area we want to see
        path.addRect(blurEffectView.bounds)
        path.addRoundedRect(in: bounds, cornerWidth: 5.0, cornerHeight: 5.0)
        return path
    }
}
