import SwiftUI

struct SurgeryTracking: View {
    @ObservedObject var model: SurgeryModel
    
    var enableDevMode: Bool = false
    
    @State private var isDevModeActive = false
    
    var body: some View {
        VStack {
            ARViewContainer(model: model)
        }
        .overlay(alignment: .top) {
            if enableDevMode && isDevModeActive {
                AxisAdjustForm(model: model)
            }
        }
        .overlay(alignment: .bottom) {
            HStack {
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
        }
        .overlay(alignment: .bottomTrailing) {
            if enableDevMode {
                HStack {
                    if isDevModeActive {
                        AsyncButton(showSuccessIndicator: true,
                            action: {
                                await model.exportScene()
                            },
                            label: {
                                Text("Export Scene")
                            })
                    }
                    Button(action: {
                        isDevModeActive.toggle()
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

#Preview("Default") {
    let model = SurgeryModel()
    return SurgeryTracking(model: model)
}

#Preview("Dev mode") {
    let model = SurgeryModel()
    return SurgeryTracking(model: model, enableDevMode: true)
}
