import SwiftUI

@main
struct CalPalApp: App {
    @StateObject private var appModel = AppModel(dependencies: .live)

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(appModel)
                .environmentObject(appModel.commandHomeModel)
        }
    }
}
