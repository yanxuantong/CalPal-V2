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
    var parseRoute: CalendarParseRoute = .deterministicFallback

    var isHighConfidence: Bool { confidence >= 0.85 && missingFields.isEmpty && warnings.isEmpty }
}

enum CalendarParseRoute: String, Equatable, Codable, Hashable {
    case deterministicFallback
    case foundationModelsGenerated
    case foundationModelsUnavailable
    case foundationModelsFailedOver
    case foundationModelsLocaleUnsupported

    var resultLabel: String {
        switch self {
        case .foundationModelsGenerated:
            return "Apple Intelligence"
        case .deterministicFallback:
            return "Local parser"
        case .foundationModelsUnavailable:
            return "Local parser - AI unavailable"
        case .foundationModelsFailedOver:
            return "Local parser - AI fallback"
        case .foundationModelsLocaleUnsupported:
            return "Local parser - locale fallback"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .foundationModelsGenerated:
            return "Parsed by Apple Intelligence"
        case .deterministicFallback:
            return "Parsed by the local deterministic parser"
        case .foundationModelsUnavailable:
            return "Parsed locally because Apple Intelligence was unavailable"
        case .foundationModelsFailedOver:
            return "Parsed locally after Apple Intelligence failed"
        case .foundationModelsLocaleUnsupported:
            return "Parsed locally because this locale was unsupported by Apple Intelligence"
        }
    }
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
    var actionURL: URL? = nil
    var parseRoute: CalendarParseRoute? = nil
}

struct ErrorPresentation: Identifiable, Equatable {
    var id = UUID()
    var title: String
    var message: String
    var recovery: String?
}
