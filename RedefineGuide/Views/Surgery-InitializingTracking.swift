import SwiftUI

struct SurgeryInitializingTracking: View {
    @ObservedObject var model: SurgeryModel
    
    var body: some View {
        VStack {
            ARViewContainer(model: model)
                .opacity(0.5) // to indicate they can't do anything during this.  you could also do brightness
        }
        .overlay(alignment: .center) {
            VStack {
                Text("Locking Onto Femur")
                    .font(.title)
                ProgressView()
                    .scaleEffect(2)
                    .padding()
            }
        }
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

#Preview {
    let model = SurgeryModel()
    return SurgeryInitializingTracking(model: model)
}
