import SwiftUI

struct SurgeryStarting: View {
    @ObservedObject var model: SurgeryModel
    
    var body: some View {
        Centered {
            VStack {
                Text("Loading Patient Data")
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
    return SurgeryStarting(model: model)
}
