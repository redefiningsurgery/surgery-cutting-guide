import SwiftUI

/// The live view of surgery.
struct SurgeryView: View {
    @ObservedObject var model: SurgeryModel

    var body: some View {
        VStack {
            ARViewContainer(model: model)
                .onTapGesture { location in
                    model.onTap(point: location)
                }
            HStack {
                Toggle(isOn: $model.showLeadingCube) {
                    Text("Show Leading Cube")
                      .frame(maxWidth: .infinity, alignment: .trailing)
                }
                Spacer()
                Button("Reset Center") {
                    model.resetWorldOrigin()
                }
            }
        }
    }
}

#Preview {
    return SurgeryView(model: SurgeryModel())
}
