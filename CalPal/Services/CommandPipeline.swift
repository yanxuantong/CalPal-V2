import Foundation

protocol CalendarCommandPipelineProtocol {
    func process(text: String) async -> CalendarCommandPipelineOutput
    func apply(draft: EventDraft) async -> CalendarCommandPipelineOutput
    func confirm(_ context: ConfirmationContext, decision: ConfirmationDecision) async -> CalendarCommandPipelineOutput
}

enum CalendarCommandPipelineOutput: Equatable {
    case result(CommandResultViewState)
    case correction(CorrectionContext)
    case confirmation(ConfirmationContext)
    case candidateSelection(CandidateSelectionContext)
    case calendarChooser(CalendarChooserContext)
    case unavailable(UnavailableContext)
    case failure(ErrorPresentation)
}

final class CalendarCommandPipeline: CalendarCommandPipelineProtocol {
    private let parser: CalendarCommandParsing
    private let policy: CalendarMutationPolicy
    private let repository: CalendarRepositoryProtocol

    init(parser: CalendarCommandParsing, policy: CalendarMutationPolicy, repository: CalendarRepositoryProtocol) {
        self.parser = parser
        self.policy = policy
        self.repository = repository
    }

    func process(text: String) async -> CalendarCommandPipelineOutput {
        let parsed = await parser.parseCommand(text)
        if parsed.requiresCalendarRead {
            let status = await repository.requestFullAccessIfNeeded()
            guard status == .allowed else {
                return .unavailable(UnavailableContext(title: "Calendar Access Needed", message: "Full access is required to find, modify, or delete existing events.", primaryAction: .openSettings, secondaryAction: nil))
            }
        }
        let calendars = (try? await repository.fetchCalendars()) ?? []
        switch await policy.decide(parsed: parsed, calendars: calendars, repository: repository) {
        case .autoApply(let draft):
            return await apply(draft: draft).annotatingResult(parseRoute: parsed.parseRoute)
        case .needsCorrection(let context): return .correction(context)
        case .needsConfirmation(let context): return .confirmation(context)
        case .needsCandidateSelection(let context): return .candidateSelection(context)
        case .unavailable(let context): return .unavailable(context)
        }
    }

    func apply(draft: EventDraft) async -> CalendarCommandPipelineOutput {
        do {
            let status = await repository.requestFullAccessIfNeeded()
            guard status == .allowed else { throw CalendarRepositoryError.accessDenied }
            let event = try await repository.createEvent(draft)
            return .result(CommandResultViewState(title: "Added to Calendar", message: "\(event.title) · \(event.formattedRange)", event: event, actionTitle: "Open in Calendar", actionURL: CalendarDeepLink.appleCalendarURL(for: event.startDate)))
        } catch CalendarRepositoryError.accessDenied {
            return .unavailable(UnavailableContext(title: "Calendar Access Needed", message: "Allow full calendar access before saving events to Apple Calendar.", primaryAction: .openSettings, secondaryAction: nil))
        } catch {
            return .failure(ErrorPresentation(title: "Could Not Save Event", message: error.localizedDescription, recovery: "Review the details or create manually."))
        }
    }

    func confirm(_ context: ConfirmationContext, decision: ConfirmationDecision) async -> CalendarCommandPipelineOutput {
        guard case .confirm(let recurrenceScope) = decision else {
            return .failure(ErrorPresentation(title: "Change Cancelled", message: "No calendar changes were made.", recovery: nil))
        }
        do {
            switch context.operation {
            case .create:
                if let draft = context.afterDraft {
                    return await apply(draft: draft).annotatingResult(parseRoute: context.parseRoute)
                }
                return .failure(ErrorPresentation(title: "Missing Draft", message: "The event details were unavailable.", recovery: "Try again."))
            case .modify:
                guard let id = context.targetEventID, let patch = context.patch else { throw CalendarRepositoryError.eventNotFound }
                let event = try await repository.updateEvent(id: id, patch: patch, recurrenceScope: recurrenceScope ?? context.recurrenceScope)
                return .result(CommandResultViewState(title: "Updated Calendar", message: "\(event.title) · \(event.formattedRange)", event: event, actionTitle: "Open in Calendar", actionURL: CalendarDeepLink.appleCalendarURL(for: event.startDate), parseRoute: context.parseRoute))
            case .delete:
                guard let id = context.targetEventID else { throw CalendarRepositoryError.eventNotFound }
                try await repository.deleteEvent(id: id, recurrenceScope: recurrenceScope ?? context.recurrenceScope)
                return .result(CommandResultViewState(title: "Deleted Event", message: context.before?.title ?? "Calendar event removed", event: nil, actionTitle: nil, parseRoute: context.parseRoute))
            }
        } catch {
            return .failure(ErrorPresentation(title: "Calendar Change Failed", message: error.localizedDescription, recovery: "Re-fetch the agenda and try again."))
        }
    }
}

private extension CalendarCommandPipelineOutput {
    func annotatingResult(parseRoute: CalendarParseRoute) -> CalendarCommandPipelineOutput {
        annotatingResult(parseRoute: Optional(parseRoute))
    }

    func annotatingResult(parseRoute: CalendarParseRoute?) -> CalendarCommandPipelineOutput {
        guard case .result(var result) = self else { return self }
        result.parseRoute = parseRoute
        return .result(result)
    }
}

extension CalendarEvent {
    var formattedRange: String {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return "\(f.string(from: startDate))–\(f.string(from: endDate))"
    }
}

private extension ParsedCalendarCommand {
    var requiresCalendarRead: Bool {
        guard let intent else { return false }
        switch intent {
        case .create: return false
        case .modify, .delete: return true
        }
    }
}
