import SwiftUI

/// The live view of surgery.
struct SurgeryView: View {
    @ObservedObject var model: SurgeryModel
    
    @ObservedObject var settings: Settings = Settings.shared

    var body: some View {
        if model.phase == .notStarted {
            SurgeryNotStarted(model: model)
        } else if model.phase == .done {
            SurgeryDone(model: model)
        } else if model.phase == .starting {
            SurgeryStarting(model: model)
        } else if model.phase == .aligning {
            SurgeryAligning(model: model)
        } else if model.phase == .initializingTracking {
            SurgeryInitializingTracking(model: model)
        } else {
            SurgeryTracking(model: model, isDevOverlayVisible: settings.enableDevMode)
        }
    }
}

#Preview("Not Started") {
    let model = SurgeryModel()
    model.phase = .notStarted
    return SurgeryView(model: model)
}

#Preview("Starting") {
    let model = SurgeryModel()
    model.phase = .starting
    return SurgeryView(model: model)
}

#Preview("Aligning") {
    let model = SurgeryModel()
    model.phase = .aligning
    return SurgeryView(model: model)
}

#Preview("Initializing Tracking") {
    let model = SurgeryModel()
    model.phase = .initializingTracking
    return SurgeryView(model: model)
}

#Preview("Tracking") {
    let model = SurgeryModel()
    model.phase = .tracking
    return SurgeryView(model: model)
}

#Preview("Done") {
    let model = SurgeryModel()
    model.phase = .done
    return SurgeryView(model: model)
}
