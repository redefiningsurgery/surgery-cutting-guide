import SwiftUI

struct SurgeryDone: View {
    @ObservedObject var model: SurgeryModel
    
    var body: some View {
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
}

#Preview {
    let model = SurgeryModel()
    return SurgeryDone(model: model)
}
