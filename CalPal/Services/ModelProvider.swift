import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

protocol ModelProviderProtocol {
    func availability() -> PermissionStatus
}

protocol CalendarCommandParsing {
    func parseCommand(_ text: String) async -> ParsedCalendarCommand
}

extension NaturalLanguageCalendarParser: CalendarCommandParsing {
    func parseCommand(_ text: String) async -> ParsedCalendarCommand { parse(text) }
}

struct LocalFoundationModelProvider: ModelProviderProtocol {
    func availability() -> PermissionStatus {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return .allowed
            case .unavailable(.appleIntelligenceNotEnabled), .unavailable(.modelNotReady):
                return .notDetermined
            case .unavailable(.deviceNotEligible):
                return .unavailable
            case .unavailable:
                return .unknown
            @unknown default:
                return .unknown
            }
        }
        #endif
        return .unavailable
    }
}

final class FoundationModelsCalendarParser: CalendarCommandParsing {
    private let fallback: NaturalLanguageCalendarParser
    private let modelProvider: ModelProviderProtocol
    private let isoFormatter: ISO8601DateFormatter

    init(fallback: NaturalLanguageCalendarParser, modelProvider: ModelProviderProtocol = LocalFoundationModelProvider()) {
        self.fallback = fallback
        self.modelProvider = modelProvider
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.isoFormatter = formatter
    }

    func parseCommand(_ text: String) async -> ParsedCalendarCommand {
        guard modelProvider.availability() == .allowed else {
            return fallback.parse(text)
        }
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            do {
                let session = LanguageModelSession(instructions: Self.instructions)
                let response = try await session.respond(
                    to: Self.prompt(for: text),
                    generating: FoundationCalendarCommand.self,
                    options: GenerationOptions(temperature: 0.0)
                )
                return map(response.content, originalText: text) ?? fallback.parse(text)
            } catch {
                var parsed = fallback.parse(text)
                parsed.warnings.append("Foundation Models parsing unavailable; used local fallback")
                return parsed
            }
        }
        #endif
        return fallback.parse(text)
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private func map(_ command: FoundationCalendarCommand, originalText: String) -> ParsedCalendarCommand? {
        let locale = command.localeIdentifier.isEmpty ? (containsChinese(originalText) ? "zh-Hans" : Locale.current.identifier) : command.localeIdentifier
        let missing = command.missingFields.filter { !$0.isEmpty }
        let warnings = command.warnings.filter { !$0.isEmpty }
        let confidence = max(0, min(command.confidence, 1))
        switch command.intent.lowercased() {
        case "create":
            let start = date(from: command.startDateISO)
            let end = date(from: command.endDateISO) ?? start?.addingTimeInterval(3600)
            let draft = EventDraft(
                title: command.title.trimmingCharacters(in: .whitespacesAndNewlines),
                startDate: start ?? Date(),
                endDate: end ?? Date().addingTimeInterval(3600),
                calendarID: nil,
                calendarName: nil,
                location: command.location.nilIfEmpty,
                notes: command.notes.nilIfEmpty,
                isAllDay: command.isAllDay
            )
            let computedMissing = missing + (start == nil ? ["time"] : []) + (draft.title.isEmpty ? ["title"] : [])
            return ParsedCalendarCommand(originalText: originalText, localeIdentifier: locale, intent: .create(draft), confidence: confidence, missingFields: Array(Set(computedMissing)), warnings: warnings)
        case "modify":
            let patch = EventPatch(
                title: command.title.nilIfEmpty,
                startDate: date(from: command.startDateISO),
                endDate: date(from: command.endDateISO),
                location: command.location.nilIfEmpty,
                notes: command.notes.nilIfEmpty
            )
            return ParsedCalendarCommand(originalText: originalText, localeIdentifier: locale, intent: .modify(query: query(from: command, originalText: originalText), patch: patch), confidence: confidence, missingFields: missing, warnings: warnings)
        case "delete":
            return ParsedCalendarCommand(originalText: originalText, localeIdentifier: locale, intent: .delete(query: query(from: command, originalText: originalText)), confidence: confidence, missingFields: missing, warnings: warnings)
        default:
            return ParsedCalendarCommand(originalText: originalText, localeIdentifier: locale, intent: nil, confidence: confidence, missingFields: missing.isEmpty ? ["intent"] : missing, warnings: warnings)
        }
    }

    @available(iOS 26.0, *)
    private func query(from command: FoundationCalendarCommand, originalText: String) -> EventQuery {
        EventQuery(
            phrase: originalText,
            day: date(from: command.targetDateISO).map { Calendar.current.startOfDay(for: $0) },
            titleHint: command.targetHint.nilIfEmpty ?? command.title.nilIfEmpty,
            boundedDays: 14
        )
    }
    #endif

    private func date(from text: String) -> Date? {
        guard !text.isEmpty else { return nil }
        return isoFormatter.date(from: text) ?? ISO8601DateFormatter().date(from: text)
    }

    private func containsChinese(_ text: String) -> Bool {
        text.unicodeScalars.contains { $0.value >= 0x4E00 && $0.value <= 0x9FFF }
    }

    private static let instructions = """
    You extract calendar commands into strict fields for a privacy-first iOS calendar assistant.
    Return create, modify, delete, or unknown only. Use ISO-8601 dates when the user gives a clear date/time.
    Mark missingFields when title, target event, or time is ambiguous. Do not invent far-future dates.
    Confidence must be 0...1 and lower than 0.7 when required information is missing.
    """

    private static func prompt(for text: String) -> String {
        """
        User calendar command:
        \(text)

        Extract a calendar intent. For modify/delete, targetHint is the event to search for. For create, title/start/end are the new event.
        """
    }
}

#if canImport(FoundationModels)
@available(iOS 26.0, *)
@Generable(description: "Structured calendar command extracted from natural language")
struct FoundationCalendarCommand {
    @Guide(description: "One of: create, modify, delete, unknown")
    var intent: String
    @Guide(description: "BCP-47 locale identifier such as en-US or zh-Hans")
    var localeIdentifier: String
    @Guide(description: "Event title or new title; empty string if unknown")
    var title: String
    @Guide(description: "Target event title or phrase for modify/delete; empty string if not applicable")
    var targetHint: String
    @Guide(description: "ISO-8601 target/search day for modify/delete; empty string if unknown")
    var targetDateISO: String
    @Guide(description: "ISO-8601 start date/time; empty string if unknown")
    var startDateISO: String
    @Guide(description: "ISO-8601 end date/time; empty string if unknown")
    var endDateISO: String
    @Guide(description: "Event location; empty string if absent")
    var location: String
    @Guide(description: "Event notes; empty string if absent")
    var notes: String
    var isAllDay: Bool
    @Guide(description: "Extraction confidence from 0 to 1", .range(0.0...1.0))
    var confidence: Double
    var missingFields: [String]
    var warnings: [String]
}
#endif

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

struct MockModelProvider: ModelProviderProtocol {
    func availability() -> PermissionStatus { .allowed }
}
