import SwiftUI

struct SurgeryView: View {
    @ObservedObject var model: SurgeryModel
    
    @ObservedObject var settings: Settings

    var body: some View {
        if model.phase == .notStarted {
            SurgeryNotStarted(model: model)
        } else if model.phase == .done {
            SurgeryDone(model: model)
        } else if model.phase == .starting {
            SurgeryStarting(model: model)
                .showErrors(model)
        } else if model.phase == .aligning {
            SurgeryAligning(model: model)
                .showErrors(model)
        } else if model.phase == .initializingTracking {
            SurgeryInitializingTracking(model: model)
                .showErrors(model)
        } else {
            SurgeryTracking(model: model, settings: settings)
                .showErrors(model)
        }
    }
}

struct ShowErrorsModifier: ViewModifier {
    @ObservedObject var model: SurgeryModel

    func body(content: Content) -> some View {
        content
            .alert(model.errorTitle, isPresented: $model.errorVisible) {
                Button(role: .cancel) {
                    model.phase = .notStarted
                } label: {
                    Text("OK")
                }
            } message: {
                Text(model.errorMessage)
            }
    }
}

extension View {
    // makes it easy to show errors from the model
    func showErrors(_ model: SurgeryModel) -> some View {
        modifier(ShowErrorsModifier(model: model))
    }
}

#Preview("Not Started") {
    let model = SurgeryModel()
    model.phase = .notStarted
    return SurgeryView(model: model, settings: Settings())
}

#Preview("Starting") {
    let model = SurgeryModel()
    model.phase = .starting
    return SurgeryView(model: model, settings: Settings())
}

#Preview("Aligning") {
    let model = SurgeryModel()
    model.phase = .aligning
    return SurgeryView(model: model, settings: Settings())
}

#Preview("Initializing Tracking") {
    let model = SurgeryModel()
    model.phase = .initializingTracking
    return SurgeryView(model: model, settings: Settings())
}

#Preview("Tracking") {
    let model = SurgeryModel()
    model.phase = .tracking
    return SurgeryView(model: model, settings: Settings())
}

#Preview("Done") {
    let model = SurgeryModel()
    model.phase = .done
    return SurgeryView(model: model, settings: Settings())
}
