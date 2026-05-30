import Foundation

enum PermissionStatus: String, Codable, Equatable {
    case unknown
    case notDetermined
    case allowed
    case denied
    case restricted
    case unavailable
}

struct CapabilitySummary: Equatable, Codable {
    var calendar: PermissionStatus
    var speech: PermissionStatus
    var model: PermissionStatus
    var preferredLocales: [String]
    var runsOnDevice: Bool

    static let optimistic = CapabilitySummary(calendar: .unknown, speech: .unknown, model: .allowed, preferredLocales: ["en-US", "zh-Hans"], runsOnDevice: true)
}

enum SettingsSection: String, Identifiable, CaseIterable {
    case privacy
    case diagnostics
    case language
    case automation

    var id: String { rawValue }

    var title: String {
        switch self {
        case .language:
            return "Default Calendar"
        case .automation:
            return "Safety Mode"
        case .diagnostics:
            return "1.0 Launch Readiness"
        case .privacy:
            return "Local Preferences"
        }
    }

    var accessibilityIdentifier: String {
        "settingsSection-\(rawValue)"
    }
}
