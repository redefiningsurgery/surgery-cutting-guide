import SwiftUI

struct SurgeryDone: View {
    @ObservedObject var model: SurgeryModel
    
    var body: some View {
        Centered {
            Centered {
                VStack {
                    Spacer()
                    Text("Done!")
                        .font(.title)
                    Spacer()
                    Button("Start new Pin Placement") {
                        model.startSession()
                    }
                    Spacer()
                }
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
