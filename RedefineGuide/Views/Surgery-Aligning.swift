import SwiftUI

struct SurgeryAligning: View {
    @ObservedObject var model: SurgeryModel
    
    var body: some View {
        VStack {
            ARViewContainer(model: model)
        }
        .overlay(alignment: .center) {
            Image("Overlay")
                .resizable()
                .scaledToFit()
                .frame(width: 300)
        }
        .overlay(alignment: .bottomTrailing) {
            HStack {
                Button(action: {
                    model.startTracking()
                }, label: {
                    Text("Track")
                        .padding(8)
                        .fontWeight(.heavy)
                        .foregroundColor(.white)
                        .background(.primaryGreen, in: .rect(cornerRadius: 4))
                })
                ConfirmButton(action: {
                    model.stopSession()
                }, label: {
                    Text("Cancel")
                })
                .alertTitle("Are you sure?")
                .alertMessage("Do you really want to cancel this procedure?")
                .alertCancelButton("No")
                .alertConfirmButton("Yes")
            }
            .padding()
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
    return SurgeryAligning(model: model)
}
