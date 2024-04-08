import SwiftUI

struct RootView: View {
    @ObservedObject var model: AppInitializationModel
    
    var body: some View {
        switch model.status {
        case .initializing:
            Centered {
                ProgressView()
            }
        case .failed(let error):
            Centered {
                Text(error)
            }
        case .initialized:
            let controller = ARViewController()
            SurgeryView(model: controller.model)
                //.edgesIgnoringSafeArea(.all)
        }
    }
}

#Preview("Initializing") {
    let model = AppInitializationModel()
    model.status = .initializing
    return RootView(model: model)
}

#Preview("Error") {
    let model = AppInitializationModel()
    model.status = .failed("You are not cool enough.")
    return RootView(model: model)
}

#Preview("Initialized") {
    let model = AppInitializationModel()
    model.status = .initialized
    return RootView(model: model)
}

