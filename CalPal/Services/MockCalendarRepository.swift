import Foundation

final class MockCalendarRepository: CalendarRepositoryProtocol {
    private var events: [CalendarEvent]
    var calendars: [CalendarInfo]
    private let calendar = Calendar.current
    var authorization: PermissionStatus = .allowed
    private(set) var requestFullAccessCount = 0
    private(set) var createdDrafts: [EventDraft] = []

    init(now: Date = PreviewFixtures.now) {
        calendars = [
            CalendarInfo(id: "work", title: "Work Calendar", accountName: "iCloud", allowsContentModifications: true, colorHex: "#0A84FF"),
            CalendarInfo(id: "personal", title: "Personal", accountName: "Google", allowsContentModifications: true, colorHex: "#30D158"),
            CalendarInfo(id: "family", title: "Family", accountName: "iCloud", allowsContentModifications: false, colorHex: "#FF9F0A")
        ]
        let day = calendar.startOfDay(for: now)
        events = [
            CalendarEvent(id: "standup", title: "Team standup", calendarID: "work", calendarName: "Work Calendar", accountName: "iCloud", startDate: day.addingTimeInterval(9*3600), endDate: day.addingTimeInterval(9*3600+1800), isAllDay: false, location: nil, notes: nil, isRecurring: false, calendarColorHex: "#0A84FF"),
            CalendarEvent(id: "focus", title: "Deep work", calendarID: "personal", calendarName: "Personal", accountName: "Google", startDate: day.addingTimeInterval(10*3600+1800), endDate: day.addingTimeInterval(12*3600), isAllDay: false, location: nil, notes: nil, isRecurring: false, calendarColorHex: "#30D158"),
            CalendarEvent(id: "alex", title: "Alex 1:1", calendarID: "work", calendarName: "Work Calendar", accountName: "iCloud", startDate: day.addingTimeInterval(15*3600), endDate: day.addingTimeInterval(16*3600), isAllDay: false, location: nil, notes: nil, isRecurring: true, calendarColorHex: "#0A84FF")
        ]
    }

    func authorizationStatus() -> PermissionStatus { authorization }
    func requestFullAccessIfNeeded() async -> PermissionStatus {
        requestFullAccessCount += 1
        return authorization
    }
    func fetchCalendars() async throws -> [CalendarInfo] { calendars }

    func fetchEvents(for day: Date) async throws -> [CalendarEvent] {
        let interval = calendar.dateInterval(of: .day, for: day) ?? DateInterval(start: day, duration: 86400)
        return events.filter { $0.startDate < interval.end && $0.endDate > interval.start }.sorted { $0.startDate < $1.startDate }
    }

    func searchEvents(query: EventQuery) async throws -> [CalendarEvent] {
        let center = query.day ?? Date()
        let start = calendar.date(byAdding: .day, value: -query.boundedDays, to: center) ?? center
        let end = calendar.date(byAdding: .day, value: query.boundedDays, to: center) ?? center
        let hint = query.titleHint?.lowercased()
        return events.filter { event in
            event.startDate >= start && event.startDate <= end && (hint == nil || event.title.lowercased().contains(hint!))
        }
    }

    func createEvent(_ draft: EventDraft) async throws -> CalendarEvent {
        createdDrafts.append(draft)
        guard let calendarInfo = calendars.first(where: { $0.id == (draft.calendarID ?? "work") }) ?? calendars.first(where: { $0.allowsContentModifications }) else { throw CalendarRepositoryError.noWritableCalendar }
        let event = CalendarEvent(id: UUID().uuidString, title: draft.title, calendarID: calendarInfo.id, calendarName: calendarInfo.title, accountName: calendarInfo.accountName, startDate: draft.startDate, endDate: draft.endDate, isAllDay: draft.isAllDay, location: draft.location, notes: draft.notes, isRecurring: false, calendarColorHex: calendarInfo.colorHex)
        events.append(event)
        return event
    }

    func updateEvent(id: String, patch: EventPatch, recurrenceScope: RecurrenceChangeScope?) async throws -> CalendarEvent {
        guard let idx = events.firstIndex(where: { $0.id == id }) else { throw CalendarRepositoryError.eventNotFound }
        if let title = patch.title { events[idx].title = title }
        if let start = patch.startDate { events[idx].startDate = start }
        if let end = patch.endDate { events[idx].endDate = end }
        if let location = patch.location { events[idx].location = location }
        if let notes = patch.notes { events[idx].notes = notes }
        return events[idx]
    }

    func deleteEvent(id: String, recurrenceScope: RecurrenceChangeScope?) async throws {
        events.removeAll { $0.id == id }
    }
}
