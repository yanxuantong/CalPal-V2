import Foundation

protocol CalendarRepositoryProtocol {
    func authorizationStatus() -> PermissionStatus
    func requestFullAccessIfNeeded() async -> PermissionStatus
    func fetchCalendars() async throws -> [CalendarInfo]
    func fetchEvents(for day: Date) async throws -> [CalendarEvent]
    func searchEvents(query: EventQuery) async throws -> [CalendarEvent]
    func createEvent(_ draft: EventDraft) async throws -> CalendarEvent
    func updateEvent(id: String, patch: EventPatch, recurrenceScope: RecurrenceChangeScope?) async throws -> CalendarEvent
    func deleteEvent(id: String, recurrenceScope: RecurrenceChangeScope?) async throws
}

enum CalendarRepositoryError: LocalizedError, Equatable {
    case accessDenied
    case noWritableCalendar
    case eventNotFound
    case invalidDraft(String)

    var errorDescription: String? {
        switch self {
        case .accessDenied: return "Calendar access is denied."
        case .noWritableCalendar: return "No writable calendar is available."
        case .eventNotFound: return "The event could not be found."
        case .invalidDraft(let message): return message
        }
    }
}
