import EventKit
import Foundation
import UIKit

final class EventKitCalendarRepository: CalendarRepositoryProtocol {
    private let store = EKEventStore()
    private let calendar: Calendar

    init(calendar: Calendar = .autoupdatingCurrent) { self.calendar = calendar }

    func authorizationStatus() -> PermissionStatus {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .authorized, .fullAccess: return .allowed
        case .denied: return .denied
        case .restricted: return .restricted
        case .notDetermined: return .notDetermined
        case .writeOnly: return .restricted
        @unknown default: return .unknown
        }
    }

    func requestFullAccessIfNeeded() async -> PermissionStatus {
        let current = authorizationStatus()
        guard current == .notDetermined || current == .unknown else { return current }
        let granted: Bool
        if #available(iOS 17.0, *) {
            granted = (try? await store.requestFullAccessToEvents()) ?? false
        } else {
            granted = (try? await store.requestAccess(to: .event)) ?? false
        }
        return granted ? .allowed : authorizationStatus()
    }

    func fetchCalendars() async throws -> [CalendarInfo] {
        try ensureAccess()
        return store.calendars(for: .event).map { ek in
            CalendarInfo(id: ek.calendarIdentifier, title: ek.title, accountName: ek.source.title, allowsContentModifications: ek.allowsContentModifications, colorHex: ek.cgColor.hexString)
        }
    }

    func fetchEvents(for day: Date) async throws -> [CalendarEvent] {
        try ensureAccess()
        let interval = calendar.dateInterval(of: .day, for: day) ?? DateInterval(start: day, duration: 86400)
        let predicate = store.predicateForEvents(withStart: interval.start, end: interval.end, calendars: nil)
        return store.events(matching: predicate).sorted { $0.startDate < $1.startDate }.map(mapEvent)
    }

    func searchEvents(query: EventQuery) async throws -> [CalendarEvent] {
        try ensureAccess()
        let center = query.day ?? Date()
        let start = calendar.date(byAdding: .day, value: -query.boundedDays, to: center) ?? center
        let end = calendar.date(byAdding: .day, value: query.boundedDays, to: center) ?? center
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        let normalizedHint = query.titleHint?.lowercased()
        return store.events(matching: predicate)
            .filter { event in
                guard let hint = normalizedHint, !hint.isEmpty else { return true }
                return event.title.lowercased().contains(hint)
            }
            .sorted { $0.startDate < $1.startDate }
            .map(mapEvent)
    }

    func createEvent(_ draft: EventDraft) async throws -> CalendarEvent {
        try ensureAccess()
        guard draft.hasRequiredFields else { throw CalendarRepositoryError.invalidDraft("Title and a valid time range are required.") }
        let event = EKEvent(eventStore: store)
        event.title = draft.title
        event.startDate = draft.startDate
        event.endDate = draft.endDate
        event.isAllDay = draft.isAllDay
        event.location = draft.location
        event.notes = draft.notes
        event.calendar = try writableCalendar(preferredID: draft.calendarID)
        try store.save(event, span: .thisEvent, commit: true)
        guard let eventIdentifier = event.eventIdentifier, !eventIdentifier.isEmpty else {
            throw CalendarRepositoryError.invalidDraft("Calendar save did not return a persistent event identifier.")
        }
        guard let verifiedEvent = verifiedSavedEvent(for: event, identifier: eventIdentifier) else {
            throw CalendarRepositoryError.invalidDraft("Calendar save could not be verified in the target calendar.")
        }
        return mapEvent(verifiedEvent)
    }

    func updateEvent(id: String, patch: EventPatch, recurrenceScope: RecurrenceChangeScope?) async throws -> CalendarEvent {
        try ensureAccess()
        guard let event = store.event(withIdentifier: id) else { throw CalendarRepositoryError.eventNotFound }
        if let title = patch.title { event.title = title }
        if let start = patch.startDate { event.startDate = start }
        if let end = patch.endDate { event.endDate = end }
        if let location = patch.location { event.location = location }
        if let notes = patch.notes { event.notes = notes }
        try store.save(event, span: recurrenceScope.eventKitSpan, commit: true)
        return mapEvent(event)
    }

    func deleteEvent(id: String, recurrenceScope: RecurrenceChangeScope?) async throws {
        try ensureAccess()
        guard let event = store.event(withIdentifier: id) else { throw CalendarRepositoryError.eventNotFound }
        try store.remove(event, span: recurrenceScope.eventKitSpan, commit: true)
    }

    private func ensureAccess() throws {
        guard authorizationStatus() == .allowed else { throw CalendarRepositoryError.accessDenied }
    }

    private func writableCalendar(preferredID: String?) throws -> EKCalendar {
        let calendars = store.calendars(for: .event)
        if let preferredID, let preferred = calendars.first(where: { $0.calendarIdentifier == preferredID && $0.allowsContentModifications }) {
            return preferred
        }
        if let defaultCalendar = store.defaultCalendarForNewEvents, defaultCalendar.allowsContentModifications { return defaultCalendar }
        guard let first = calendars.first(where: { $0.allowsContentModifications }) else { throw CalendarRepositoryError.noWritableCalendar }
        return first
    }

    private func verifiedSavedEvent(for event: EKEvent, identifier: String) -> EKEvent? {
        if let savedEvent = store.event(withIdentifier: identifier), matches(savedEvent, savedDraft: event) {
            return savedEvent
        }

        let interval = DateInterval(
            start: event.startDate.addingTimeInterval(-60),
            end: event.endDate.addingTimeInterval(60)
        )
        let predicate = store.predicateForEvents(withStart: interval.start, end: interval.end, calendars: [event.calendar])
        return store.events(matching: predicate).first { matches($0, savedDraft: event) }
    }

    private func matches(_ candidate: EKEvent, savedDraft event: EKEvent) -> Bool {
        candidate.calendar.calendarIdentifier == event.calendar.calendarIdentifier
            && candidate.title == event.title
            && abs(candidate.startDate.timeIntervalSince(event.startDate)) < 1
            && abs(candidate.endDate.timeIntervalSince(event.endDate)) < 1
    }

    private func mapEvent(_ event: EKEvent) -> CalendarEvent {
        CalendarEvent(id: event.eventIdentifier, title: event.title ?? "Untitled", calendarID: event.calendar.calendarIdentifier, calendarName: event.calendar.title, accountName: event.calendar.source.title, startDate: event.startDate, endDate: event.endDate, isAllDay: event.isAllDay, location: event.location, notes: event.notes, isRecurring: event.hasRecurrenceRules, calendarColorHex: event.calendar.cgColor.hexString)
    }
}

private extension Optional where Wrapped == RecurrenceChangeScope {
    var eventKitSpan: EKSpan {
        switch self {
        case .some(.futureEvents): return .futureEvents
        case .some(.thisEvent), .none: return .thisEvent
        }
    }
}

private extension CGColor {
    var hexString: String? {
        guard let comps = components, comps.count >= 3 else { return nil }
        let r = Int((comps[0] * 255).rounded())
        let g = Int((comps[1] * 255).rounded())
        let b = Int((comps[2] * 255).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
