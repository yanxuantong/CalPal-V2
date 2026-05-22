import SwiftUI

@main
struct CalPalApp: App {
    @StateObject private var appModel = AppModel(runtime: .current())

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(appModel)
                .environmentObject(appModel.commandHomeModel)
        }
    }
}
