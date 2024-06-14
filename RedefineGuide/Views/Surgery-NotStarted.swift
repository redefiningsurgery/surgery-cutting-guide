import SwiftUI

struct SurgeryNotStarted: View {
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
    }
}

#Preview {
    let model = SurgeryModel()
    model.phase = .notStarted
    return SurgeryNotStarted(model: model)
}
