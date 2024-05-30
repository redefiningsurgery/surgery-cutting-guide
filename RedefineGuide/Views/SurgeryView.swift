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
            .overlay(alignment: .top) {
                Text("Align the femur with the overlay and press the start button")
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .padding()
                    .foregroundColor(.black)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.green)
                            .opacity(0.5)
                    )
            }
            .overlay(alignment: .bottom) {
                Button(action: {
                    model.startTracking()
                }, label: {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 70, height: 70)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 6)
                                .frame(width: 76, height: 76)
                        )
                })
            }
            .overlay(alignment: .bottomTrailing) {
                ConfirmButton("Cancel") {
                    model.stopSession()
                }
                .alertTitle("Are you sure?")
                .alertMessage("Do you really want to cancel this procedure?")
                .alertCancelButton("No")
                .alertConfirmButton("Yes")
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
                    Text("This takes about 12 seconds")
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
    model.overlayBounds = CGRect(x: 100, y: 100, width: 100, height: 200)
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
