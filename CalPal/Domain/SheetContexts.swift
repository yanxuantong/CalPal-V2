import Foundation

struct TextEntryContext: Identifiable, Equatable { var id = UUID() }

struct CorrectionContext: Identifiable, Equatable {
    var id = UUID()
    var title: String
    var message: String
    var draft: EventDraft
    var missingFields: [String]
    var sourceText: String
}

struct ConfirmationContext: Identifiable, Equatable {
    var id = UUID()
    var operation: CommandOperation
    var title: String
    var message: String
    var before: CalendarEvent?
    var afterDraft: EventDraft?
    var patch: EventPatch?
    var targetEventID: String?
    var recurrenceScope: RecurrenceChangeScope?
    var isDestructive: Bool { operation == .delete }
}

struct CandidateSelectionContext: Identifiable, Equatable {
    var id = UUID()
    var operation: CommandOperation
    var candidates: [CalendarEvent]
    var patch: EventPatch?
    var sourceText: String
}

struct CalendarChooserContext: Identifiable, Equatable {
    var id = UUID()
    var calendars: [CalendarInfo]
    var selectedID: String?
}

struct ManualEventContext: Identifiable, Equatable {
    var id = UUID()
    var reason: String
    var draft: EventDraft
}

struct UnavailableContext: Identifiable, Equatable {
    var id = UUID()
    var title: String
    var message: String
    var primaryAction: UnavailableAction
    var secondaryAction: UnavailableAction?
}

enum UnavailableAction: String, Equatable, Codable, Identifiable {
    case openManualCreate
    case openTextEntry
    case openSettings
    case dismiss

    var id: String { rawValue }
    var title: String {
        switch self {
        case .openManualCreate: return "Create Manually"
        case .openTextEntry: return "Type Instead"
        case .openSettings: return "Open Settings"
        case .dismiss: return "Dismiss"
        }
    }
}

enum ConfirmationDecision: Equatable {
    case confirm(recurrenceScope: RecurrenceChangeScope?)
    case cancel
}
