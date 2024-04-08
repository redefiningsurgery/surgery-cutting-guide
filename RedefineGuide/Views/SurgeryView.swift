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
        }
    }
}

#Preview {
    return SurgeryView(model: SurgeryModel())
}
