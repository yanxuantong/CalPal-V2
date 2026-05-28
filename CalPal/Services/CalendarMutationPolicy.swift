import Foundation

final class CalendarMutationPolicy {
    private let calendar: Calendar
    private let now: () -> Date
    private let preferredCalendarID: () -> String?

    init(calendar: Calendar = .current, now: @escaping () -> Date = Date.init, preferredCalendarID: @escaping () -> String? = { nil }) {
        self.calendar = calendar
        self.now = now
        self.preferredCalendarID = preferredCalendarID
    }

    func decide(parsed: ParsedCalendarCommand, calendars: [CalendarInfo], repository: CalendarRepositoryProtocol) async -> CommandDecision {
        guard let intent = parsed.intent else {
            return .needsCorrection(defaultCorrection(parsed: parsed, calendars: calendars))
        }
        if parsed.confidence < 0.7 {
            if case .create(let draft) = intent {
                return .needsCorrection(CorrectionContext(title: "Review Event Details", message: "Some required details were missing or uncertain.", draft: applyDefaultCalendar(draft, calendars: calendars), missingFields: parsed.missingFields + parsed.warnings, sourceText: parsed.originalText, parseRoute: parsed.parseRoute))
            }
            return .needsCorrection(defaultCorrection(parsed: parsed, calendars: calendars))
        }
        switch intent {
        case .create(let draft):
            let prepared = applyDefaultCalendar(draft, calendars: calendars)
            guard prepared.hasRequiredFields else {
                return .needsCorrection(CorrectionContext(title: "Complete Event", message: "Add the missing fields before saving.", draft: prepared, missingFields: parsed.missingFields, sourceText: parsed.originalText, parseRoute: parsed.parseRoute))
            }
            if !parsed.warnings.isEmpty {
                return .needsCorrection(CorrectionContext(title: "Check Date", message: parsed.warnings.joined(separator: "\n"), draft: prepared, missingFields: parsed.warnings, sourceText: parsed.originalText, parseRoute: parsed.parseRoute))
            }
            return .autoApply(prepared)
        case .modify(let query, let patch):
            return await candidateDecision(operation: .modify, query: query, patch: patch, sourceText: parsed.originalText, parseRoute: parsed.parseRoute, repository: repository)
        case .delete(let query):
            return await candidateDecision(operation: .delete, query: query, patch: nil, sourceText: parsed.originalText, parseRoute: parsed.parseRoute, repository: repository)
        }
    }

    private func candidateDecision(operation: CommandOperation, query: EventQuery, patch: EventPatch?, sourceText: String, parseRoute: CalendarParseRoute, repository: CalendarRepositoryProtocol) async -> CommandDecision {
        do {
            let candidates = try await repository.searchEvents(query: query)
            if candidates.count == 1, let target = candidates.first {
                return .needsConfirmation(confirmationContext(operation: operation, target: target, patch: patch, parseRoute: parseRoute))
            }
            if candidates.isEmpty {
                return .needsCorrection(CorrectionContext(title: "No Matching Event", message: "Refine the event title or choose a manual fallback.", draft: EventDraft(title: query.titleHint ?? "", startDate: query.day ?? now(), endDate: (query.day ?? now()).addingTimeInterval(3600), calendarID: nil, calendarName: nil, location: nil, notes: nil), missingFields: ["matching event"], sourceText: sourceText, parseRoute: parseRoute))
            }
            return .needsCandidateSelection(CandidateSelectionContext(operation: operation, candidates: candidates, patch: patch, sourceText: sourceText, parseRoute: parseRoute))
        } catch CalendarRepositoryError.accessDenied {
            return .unavailable(UnavailableContext(title: "Calendar Access Needed", message: "Allow full calendar access before CalPal searches existing events.", primaryAction: .openSystemSettings, secondaryAction: .openSettings))
        } catch {
            return .unavailable(UnavailableContext(title: "Calendar Unavailable", message: error.localizedDescription, primaryAction: .openManualCreate, secondaryAction: .openSettings))
        }
    }

    private func confirmationContext(operation: CommandOperation, target: CalendarEvent, patch: EventPatch?, parseRoute: CalendarParseRoute?) -> ConfirmationContext {
        let recurringMessage = "This is a repeating event. Choose whether to change only this occurrence or this and future events."
        let standardMessage = operation == .delete ? "This will remove the event from your calendar." : "Confirm before changing your calendar."
        return ConfirmationContext(
            operation: operation,
            title: operation == .delete ? "Delete Event?" : "Review Change",
            message: target.isRecurring ? recurringMessage : standardMessage,
            before: target,
            afterDraft: nil,
            patch: patch,
            targetEventID: target.id,
            recurrenceScope: target.isRecurring ? .thisEvent : nil,
            parseRoute: parseRoute
        )
    }

    private func defaultCorrection(parsed: ParsedCalendarCommand, calendars: [CalendarInfo]) -> CorrectionContext {
        let start = now().addingTimeInterval(3600)
        return CorrectionContext(title: "Could Not Understand", message: "Create the event manually or try a more specific command.", draft: applyDefaultCalendar(EventDraft(title: "", startDate: start, endDate: start.addingTimeInterval(3600), calendarID: nil, calendarName: nil, location: nil, notes: nil), calendars: calendars), missingFields: parsed.missingFields, sourceText: parsed.originalText, parseRoute: parsed.parseRoute)
    }

    private func applyDefaultCalendar(_ draft: EventDraft, calendars: [CalendarInfo]) -> EventDraft {
        var copy = draft
        if copy.calendarID == nil {
            let preferredID = preferredCalendarID()
            let selected = calendars.first { $0.id == preferredID && $0.allowsContentModifications }
                ?? calendars.first(where: { $0.allowsContentModifications })
            if let selected {
                copy.calendarID = selected.id
                copy.calendarName = selected.title
            }
        }
        return copy
    }
}
