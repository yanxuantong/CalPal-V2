import Foundation

enum CalendarCommandIntent: Equatable, Codable, Hashable {
    case create(EventDraft)
    case modify(query: EventQuery, patch: EventPatch)
    case delete(query: EventQuery)
}

struct ParsedCalendarCommand: Equatable, Codable, Hashable {
    var originalText: String
    var localeIdentifier: String
    var intent: CalendarCommandIntent?
    var confidence: Double
    var missingFields: [String]
    var warnings: [String]

    var isHighConfidence: Bool { confidence >= 0.85 && missingFields.isEmpty && warnings.isEmpty }
}

enum CommandDecision: Equatable {
    case autoApply(EventDraft)
    case needsCorrection(CorrectionContext)
    case needsConfirmation(ConfirmationContext)
    case needsCandidateSelection(CandidateSelectionContext)
    case unavailable(UnavailableContext)
}

enum CommandOperation: String, Codable, Hashable {
    case create, modify, delete
}

struct CommandResultViewState: Identifiable, Equatable {
    var id = UUID()
    var title: String
    var message: String
    var event: CalendarEvent?
    var actionTitle: String?
}

struct ErrorPresentation: Identifiable, Equatable {
    var id = UUID()
    var title: String
    var message: String
    var recovery: String?
}
