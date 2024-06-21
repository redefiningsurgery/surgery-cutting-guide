import SwiftUI

/// Allows adjustment of the pin axes on the screen
struct AxisAdjustForm: View {
    @ObservedObject var model: SurgeryModel
    @ObservedObject var settings: Settings

    var body: some View {
        VStack {
            if settings.enableAxes {
                HStack {
                    VStack {
                        Text("Axis 1")
                            .font(.title3)
                        Stepper(value: $model.axis1X, in: -10...10, step: 0.0005) {
                            Text("X1: \(model.axis1X, specifier: "%.4f")")
                        }
                        Stepper(value: $model.axis1Y, in: -10...10, step: 0.0005) {
                            Text("Y1: \(model.axis1Y, specifier: "%.4f")")
                        }
                        Stepper(value: $model.axis1Z, in: -10...10, step: 0.0005) {
                            Text("Z1: \(model.axis1Z, specifier: "%.4f")")
                        }
                    }
                    VStack {
                        Text("Axis 2")
                            .font(.title3)
                        Stepper(value: $model.axis2X, in: -10...10, step: 0.0005) {
                            Text("X2: \(model.axis2X, specifier: "%.4f")")
                        }
                        Stepper(value: $model.axis2Y, in: -10...10, step: 0.0005) {
                            Text("Y2: \(model.axis2Y, specifier: "%.4f")")
                        }
                        Stepper(value: $model.axis2Z, in: -10...10, step: 0.0005) {
                            Text("Z2: \(model.axis2Z, specifier: "%.4f")")
                        }
                    }
                    VStack {
                        Text("Axes Angles")
                            .font(.title3)
                        Stepper(value: $model.axisXAngle, in: -360...360, step: 0.5) {
                            Text("X Angle: \(model.axisXAngle, specifier: "%.0f")")
                        }
                        Stepper(value: $model.axisYAngle, in: -360...360, step: 0.5) {
                            Text("Y Angle: \(model.axisYAngle, specifier: "%.0f")")
                        }
                        Stepper(value: $model.axisZAngle, in: -360...360, step: 0.5) {
                            Text("Z Angle: \(model.axisZAngle, specifier: "%.0f")")
                        }
                    }
                }
            }
            HStack {
                VStack {
                    Text("Overlay position")
                        .font(.title3)
                    Stepper(value: $model.overlayCameraOffset, in: -10...10, step: 0.0002) {
                        Text("Camera Offset: \(model.overlayCameraOffset, specifier: "%.4f")")
                    }
                    Stepper(value: $model.overlayXOffset, in: -10...10, step: 0.0002) {
                        Text("X Offset: \(model.overlayXOffset, specifier: "%.4f")")
                    }
                    Stepper(value: $model.overlayYOffset, in: -10...10, step: 0.0002) {
                        Text("Y Offset: \(model.overlayYOffset, specifier: "%.4f")")
                    }
                    Stepper(value: $model.overlayXOffset, in: -10...10, step: 0.0002) {
                        Text("Z Offset: \(model.overlayZOffset, specifier: "%.4f")")
                    }
                }
            }
            AsyncButton(showSuccessIndicator: true,
                action: {
                    await model.exportScene()
                },
                label: {
                    Text("Export Scene")
                })
        }
    }
}

#Preview {
    let settings = Settings(syncWithUserDefaults: false)
    settings.enableAxes = true
    return AxisAdjustForm(model: SurgeryModel(), settings: settings)
}
