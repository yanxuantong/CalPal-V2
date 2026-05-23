import Foundation
import OSLog
#if canImport(FoundationModels)
import FoundationModels
#endif

protocol ModelProviderProtocol {
    func availability() -> PermissionStatus
}

protocol CalendarCommandParsing {
    func parseCommand(_ text: String) async -> ParsedCalendarCommand
}

typealias FoundationCommandGenerator = (String, TimeZone, Date, Bool) async throws -> ParsedCalendarCommand?

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
    private let localTimeZone: TimeZone
    private let now: () -> Date
    private let commandGenerator: FoundationCommandGenerator?
    private let logger = Logger(subsystem: "com.calpal.mvp", category: "FoundationModels")

    init(
        fallback: NaturalLanguageCalendarParser,
        modelProvider: ModelProviderProtocol = LocalFoundationModelProvider(),
        timeZone: TimeZone = .autoupdatingCurrent,
        now: @escaping () -> Date = Date.init,
        commandGenerator: FoundationCommandGenerator? = nil
    ) {
        self.fallback = fallback
        self.modelProvider = modelProvider
        self.localTimeZone = timeZone
        self.now = now
        self.commandGenerator = commandGenerator
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.isoFormatter = formatter
    }

    func parseCommand(_ text: String) async -> ParsedCalendarCommand {
        guard modelProvider.availability() == .allowed else {
            return fallback.parse(text)
        }
        if let commandGenerator {
            do {
                guard let modelParsed = try await commandGenerator(text, localTimeZone, now(), containsChinese(text)) else {
                    return fallback.parse(text)
                }
                return fillingMissingFields(from: fallback.parse(text), in: modelParsed)
            } catch {
                logger.error("Foundation Models injected calendar parse failed: \(String(reflecting: error), privacy: .public)")
                return fallback.parse(text)
            }
        }
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            let requestedLocale = containsChinese(text) ? Locale(identifier: "zh-Hans") : Locale(identifier: "en-US")
            guard SystemLanguageModel.default.supportsLocale(requestedLocale) else {
                logger.error("Foundation Models locale unsupported: \(requestedLocale.identifier, privacy: .public)")
                return fallback.parse(text)
            }
            do {
                let session = LanguageModelSession(instructions: Self.instructions)
                let response = try await session.respond(
                    to: Self.prompt(for: text, timeZone: localTimeZone, now: now(), includesChinese: containsChinese(text)),
                    generating: FoundationCalendarCommand.self,
                    options: GenerationOptions(temperature: 0.0)
                )
                guard let modelParsed = map(response.content, originalText: text) else { return fallback.parse(text) }
                return fillingMissingFields(from: fallback.parse(text), in: modelParsed)
            } catch {
                logger.error("Foundation Models calendar parse failed: \(String(reflecting: error), privacy: .public)")
                return fallback.parse(text)
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
        return isoFormatter.date(from: text)
            ?? ISO8601DateFormatter().date(from: text)
            ?? localFloatingDateFormatter.date(from: text)
    }

    private var localFloatingDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = localTimeZone
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formatter
    }

    private func fillingMissingFields(from localParsed: ParsedCalendarCommand, in modelParsed: ParsedCalendarCommand) -> ParsedCalendarCommand {
        switch (localParsed.intent, modelParsed.intent) {
        case (.create(let localDraft), .create(var modelDraft)):
            var missingFields = modelParsed.missingFields
            if missingFields.contains("time"), !localParsed.missingFields.contains("time") {
                modelDraft.startDate = localDraft.startDate
                modelDraft.endDate = localDraft.endDate
                missingFields.removeAll { $0 == "time" }
            }
            if modelDraft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !localDraft.title.isEmpty {
                modelDraft.title = localDraft.title
                missingFields.removeAll { $0 == "title" }
            }
            return ParsedCalendarCommand(originalText: modelParsed.originalText, localeIdentifier: modelParsed.localeIdentifier, intent: .create(modelDraft), confidence: modelParsed.confidence, missingFields: missingFields, warnings: modelParsed.warnings)
        case (.modify(_, let localPatch), .modify(let query, var modelPatch)):
            if modelParsed.missingFields.contains("new time") {
                modelPatch.startDate = localPatch.startDate ?? modelPatch.startDate
                modelPatch.endDate = localPatch.endDate ?? modelPatch.endDate
            }
            return ParsedCalendarCommand(originalText: modelParsed.originalText, localeIdentifier: modelParsed.localeIdentifier, intent: .modify(query: query, patch: modelPatch), confidence: modelParsed.confidence, missingFields: modelParsed.missingFields, warnings: modelParsed.warnings)
        default:
            return modelParsed
        }
    }

    private func containsChinese(_ text: String) -> Bool {
        text.unicodeScalars.contains { $0.value >= 0x4E00 && $0.value <= 0x9FFF }
    }

    private static let instructions = """
    You extract calendar commands into strict fields for a privacy-first iOS calendar assistant.
    Return create, modify, delete, or unknown only. Use ISO-8601 dates with the user's provided local wall-clock time and the explicit timezone offset supplied in the prompt.
    Mark missingFields when title, target event, or time is ambiguous. Do not invent far-future dates.
    Confidence must be 0...1 and lower than 0.7 when required information is missing.
    """

    private static func prompt(for text: String, timeZone: TimeZone, now: Date, includesChinese: Bool) -> String {
        let seconds = timeZone.secondsFromGMT(for: now)
        let sign = seconds >= 0 ? "+" : "-"
        let absoluteSeconds = abs(seconds)
        let offset = String(format: "%@%02d:%02d", sign, absoluteSeconds / 3600, (absoluteSeconds % 3600) / 60)
        let currentLocalDateTime = localDateTimeFormatter(timeZone: timeZone).string(from: now)
        let relativeDateGuidance = includesChinese
            ? "Resolve relative dates such as today, tonight, tomorrow, 今天, 今晚, 明天, and 下周 using this current local date."
            : "Resolve relative dates such as today, tonight, tomorrow, this Friday, and next week using this current local date."
        return """
        User calendar command:
        \(text)

        User timezone: \(timeZone.identifier) (UTC\(offset)). Treat spoken times such as "3 PM" or "下午三点" as local wall-clock times in this timezone. Do not convert local times to UTC.
        Current local date/time: \(currentLocalDateTime). \(relativeDateGuidance)

        Extract a calendar intent. For modify/delete, targetHint is the event to search for. For create, title/start/end are the new event.
        """
    }

    private static func localDateTimeFormatter(timeZone: TimeZone) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss zzz"
        return formatter
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
