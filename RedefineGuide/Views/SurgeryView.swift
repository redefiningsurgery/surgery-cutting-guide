import SwiftUI

/// The live view of surgery.
struct SurgeryView: View {
    @ObservedObject var model: SurgeryModel

    var body: some View {
        VStack {
            ARViewContainer(model: model)
            HStack {
                Toggle(isOn: $model.showOverlay) {
                    Text("Show Overlay")
                      .frame(maxWidth: .infinity, alignment: .trailing)
                }
                Spacer()
                Button("Reset Center") {
                    model.resetWorldOrigin()
                }
                AsyncButton(action: {
                    await model.saveFrame()
                }, label: {
                   Text("Save Frame")
                })
            }
        }
    }
}

#Preview {
    return SurgeryView(model: SurgeryModel())
}
