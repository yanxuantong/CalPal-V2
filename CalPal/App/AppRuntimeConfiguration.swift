import Foundation

struct AppRuntimeConfiguration {
    var dependencies: DependencyContainer
    var skipsOnboarding: Bool
    var skipsPermissionRequests: Bool
    var preloadsAgenda: Bool

    static let demoLaunchArgument = "--calpal-demo"

    static func current(arguments: [String] = ProcessInfo.processInfo.arguments) -> AppRuntimeConfiguration {
        arguments.contains(demoLaunchArgument) ? .demo : .live
    }

    static var live: AppRuntimeConfiguration {
        AppRuntimeConfiguration(
            dependencies: .live,
            skipsOnboarding: false,
            skipsPermissionRequests: false,
            preloadsAgenda: false
        )
    }

    static var demo: AppRuntimeConfiguration {
        AppRuntimeConfiguration(
            dependencies: .mock(now: Date()),
            skipsOnboarding: true,
            skipsPermissionRequests: true,
            preloadsAgenda: true
        )
    }

    static func test(
        dependencies: DependencyContainer,
        skipsOnboarding: Bool = false,
        skipsPermissionRequests: Bool = false,
        preloadsAgenda: Bool = false
    ) -> AppRuntimeConfiguration {
        AppRuntimeConfiguration(
            dependencies: dependencies,
            skipsOnboarding: skipsOnboarding,
            skipsPermissionRequests: skipsPermissionRequests,
            preloadsAgenda: preloadsAgenda
        )
    }
}
