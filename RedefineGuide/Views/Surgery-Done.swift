import SwiftUI

struct SurgeryDone: View {
    @ObservedObject var model: SurgeryModel
    
    var body: some View {
        Centered {
            VStack {
                Spacer()
                Text("Welcome to Redefine Surgery Guide")
                    .font(.title)
                Spacer()
                Button("Start Pin Placement") {
                    model.startSession()
                }
                Spacer()
            }
        }
        .overlay(alignment: .topTrailing) {
            NavigationLink(destination: SettingsForm()) {
                Image(systemName: "gearshape")
                    .imageScale(.large)
            }.padding()
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
    return SurgeryDone(model: model)
}
