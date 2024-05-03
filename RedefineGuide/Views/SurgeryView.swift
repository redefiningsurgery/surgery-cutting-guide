import SwiftUI

/// The live view of surgery.
struct SurgeryView: View {
    @ObservedObject var model: SurgeryModel

    var body: some View {
        VStack {
            ARViewContainer(model: model)
            HStack {
                Spacer()
                AsyncButton(action: {
                    await model.startSession()
                }, label: {
                    Text("Start")
                }).disabled(model.startedSession)
                Spacer()
                AsyncButton(action: {
                    await model.saveFrame()
                }, label: {
                    Text("Track")
                }).disabled(!model.startedSession)
                Spacer()
                AsyncButton(action: {
                    await model.stopSession()
                }, label: {
                    Text("Stop")
                }).disabled(!model.startedSession)
                Spacer()
            }
        }
    }
}

#Preview {
    return SurgeryView(model: SurgeryModel())
}
