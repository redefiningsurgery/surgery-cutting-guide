import SwiftUI

struct SurgeryTracking: View {
    @ObservedObject var model: SurgeryModel
    
    var enableDevMode: Bool = false
    
    @State private var isDevOverlayVisible = false

    var body: some View {
        VStack {
            ARViewContainer(model: model)
        }
        .overlay(alignment: .top) {
            if enableDevMode && isDevOverlayVisible {
                AxisAdjustForm(model: model)
            }
        }
        .overlay(alignment: .bottom) {
            Button(action: {
                model.stopSession()
            }, label: {
                Text("Stop")
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .padding(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.red))
            })
        }
        .overlay(alignment: .bottomTrailing) {
            if enableDevMode {
                HStack {
                    if isDevOverlayVisible {
                        Button("Export Scene") {
                            model.exportScene()
                        }
                    }

                    Button(action: {
                        isDevOverlayVisible.toggle()
                    }) {
                        Image(systemName: "gearshape")
                            .imageScale(.large)
                            .accessibilityLabel("Developer Tools")
                    }
                }.padding(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
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
    return SurgeryTracking(model: model, enableDevMode: true)
}
