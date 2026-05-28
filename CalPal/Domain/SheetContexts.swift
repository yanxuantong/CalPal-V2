import Foundation

struct TextEntryContext: Identifiable, Equatable { var id = UUID() }

struct CorrectionContext: Identifiable, Equatable {
    var id = UUID()
    var title: String
    var message: String
    var draft: EventDraft
    var missingFields: [String]
    var sourceText: String
    var parseRoute: CalendarParseRoute? = nil
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
    var parseRoute: CalendarParseRoute? = nil
    var isDestructive: Bool { operation == .delete }
}

struct CandidateSelectionContext: Identifiable, Equatable {
    var id = UUID()
    var operation: CommandOperation
    var candidates: [CalendarEvent]
    var patch: EventPatch?
    var sourceText: String
    var parseRoute: CalendarParseRoute? = nil
}

struct CalendarChooserContext: Identifiable, Equatable {
    var id = UUID()
    var calendars: [CalendarInfo]
    var selectedID: String?
}

struct EventDetailContext: Identifiable, Equatable {
    var id = UUID()
    var event: CalendarEvent
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
    case openSystemSettings
    case dismiss

    var id: String { rawValue }
    var title: String {
        switch self {
        case .openManualCreate: return "Create Manually"
        case .openTextEntry: return "Type Instead"
        case .openSettings: return "Open Diagnostics"
        case .openSystemSettings: return "Open iOS Settings"
        case .dismiss: return "Dismiss"
        }
    }

    var systemImage: String {
        switch self {
        case .openManualCreate: return "calendar.badge.plus"
        case .openTextEntry: return "keyboard"
        case .openSettings: return "stethoscope"
        case .openSystemSettings: return "gearshape"
        case .dismiss: return "xmark"
        }
    }
}

enum ConfirmationDecision: Equatable {
    case confirm(recurrenceScope: RecurrenceChangeScope?)
    case cancel
}
