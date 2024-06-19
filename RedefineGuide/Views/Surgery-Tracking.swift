import SwiftUI

struct SurgeryTracking: View {
    @ObservedObject var model: SurgeryModel
    @ObservedObject var settings: Settings
    
    @State private var isDevModeActive = false
    
    var body: some View {
        VStack {
            ARViewContainer(model: model)
        }
        .overlay(alignment: .top) {
            if settings.enableDevMode && isDevModeActive {
                AxisAdjustForm(model: model, settings: settings)
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
                // button to manually update tracking
                if !settings.continuouslyTrack {
                    AsyncButton(showSuccessIndicator: true, action: {
                        await model.trackOnce()
                    }, label: {
                        Text("Update")
                    })
                }
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if settings.enableDevMode {
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
    let settings = Settings()
    return SurgeryTracking(model: model, settings: settings)
}

#Preview("Dev mode") {
    let model = SurgeryModel()
    let settings = Settings()
    settings.continuouslyTrack = false
    settings.enableDevMode = true
    settings.enableAxes = true
    return SurgeryTracking(model: model, settings: settings)
}
