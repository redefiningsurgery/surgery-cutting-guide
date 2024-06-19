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
                        Text("Axis 1 position")
                            .font(.title3)
                        Stepper(value: $model.axis1X, in: -10...10, step: 0.001) {
                            Text("X1: \(model.axis1X, specifier: "%.3f")")
                        }
                        Stepper(value: $model.axis1Y, in: -10...10, step: 0.001) {
                            Text("Y1: \(model.axis1Y, specifier: "%.3f")")
                        }
                        Stepper(value: $model.axis1Z, in: -10...10, step: 0.001) {
                            Text("Z1: \(model.axis1Z, specifier: "%.3f")")
                        }
                    }
                    VStack {
                        Text("Axis 2 position")
                            .font(.title3)
                        Stepper(value: $model.axis2X, in: -10...10, step: 0.001) {
                            Text("X2: \(model.axis2X, specifier: "%.3f")")
                        }
                        Stepper(value: $model.axis2Y, in: -10...10, step: 0.001) {
                            Text("Y2: \(model.axis2Y, specifier: "%.3f")")
                        }
                        Stepper(value: $model.axis2Z, in: -10...10, step: 0.001) {
                            Text("Z2: \(model.axis2Z, specifier: "%.3f")")
                        }
                    }
                    VStack {
                        Text("Axes Angles")
                            .font(.title3)
                        Stepper(value: $model.axisXAngle, in: -360...360, step: 1.0) {
                            Text("X Angle: \(model.axisXAngle, specifier: "%.0f")")
                        }
                        Stepper(value: $model.axisYAngle, in: -360...360, step: 1.0) {
                            Text("Y Angle: \(model.axisYAngle, specifier: "%.0f")")
                        }
                        Stepper(value: $model.axisZAngle, in: -360...360, step: 1.0) {
                            Text("Z Angle: \(model.axisZAngle, specifier: "%.0f")")
                        }
                    }
                }
            }
            HStack {
                VStack {
                    Text("Overlay position")
                        .font(.title3)
                    Stepper(value: $model.overlayX, in: -10...10, step: 0.001) {
                        Text("X: \(model.overlayX, specifier: "%.3f")")
                    }
                    Stepper(value: $model.overlayY, in: -10...10, step: 0.001) {
                        Text("Y: \(model.overlayY, specifier: "%.3f")")
                    }
                    Stepper(value: $model.overlayZ, in: -10...10, step: 0.001) {
                        Text("Z: \(model.overlayZ, specifier: "%.3f")")
                    }
                }
                VStack {
                    Text("Overlay Angles")
                        .font(.title3)
                    Stepper(value: $model.overlayXAngle, in: -360...360, step: 1.0) {
                        Text("X Angle: \(model.overlayXAngle, specifier: "%.0f")")
                    }
                    Stepper(value: $model.overlayYAngle, in: -360...360, step: 1.0) {
                        Text("Y Angle: \(model.overlayYAngle, specifier: "%.0f")")
                    }
                    Stepper(value: $model.overlayZAngle, in: -360...360, step: 1.0) {
                        Text("Z Angle: \(model.overlayZAngle, specifier: "%.0f")")
                    }
                }
            }
        }
    }
}

#Preview {
    let settings = Settings(syncWithUserDefaults: false)
    settings.enableAxes = true
    return AxisAdjustForm(model: SurgeryModel(), settings: settings)
}
