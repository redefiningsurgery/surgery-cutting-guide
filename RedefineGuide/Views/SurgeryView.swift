import SwiftUI

/// The live view of surgery.
struct SurgeryView: View {
    @ObservedObject var model: SurgeryModel

    var body: some View {
        if model.phase == .notStarted {
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
        } else if model.phase == .done {
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
        } else if model.phase == .starting {
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
        } else if model.phase == .aligning {
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
        } else if model.phase == .initializingTracking {
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
        } else {
            VStack {
                ARViewContainer(model: model)
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
}

#Preview("Not Started") {
    let model = SurgeryModel()
    model.phase = .notStarted
    return SurgeryView(model: model)
}

#Preview("Starting") {
    let model = SurgeryModel()
    model.phase = .starting
    return SurgeryView(model: model)
}

#Preview("Aligning") {
    let model = SurgeryModel()
    model.phase = .aligning
    return SurgeryView(model: model)
}

#Preview("Initializing Tracking") {
    let model = SurgeryModel()
    model.phase = .initializingTracking
    return SurgeryView(model: model)
}

#Preview("Tracking") {
    let model = SurgeryModel()
    model.phase = .tracking
    return SurgeryView(model: model)
}

#Preview("Done") {
    let model = SurgeryModel()
    model.phase = .done
    return SurgeryView(model: model)
}
