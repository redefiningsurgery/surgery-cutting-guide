import SwiftUI

@main
struct RedefineGuideApp: App {
    var body: some Scene {
        let controller = AppInitializer()
        WindowGroup {
            RootView(model: controller.model)
                .task {
                    await controller.start()
                }
        }
    }
}
