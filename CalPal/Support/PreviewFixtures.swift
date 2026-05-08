import Foundation

enum PreviewFixtures {
    static let now = Calendar.current.date(from: DateComponents(year: 2026, month: 4, day: 30, hour: 12)) ?? Date()

    static var workEvent: CalendarEvent {
        let start = Calendar.current.date(from: DateComponents(year: 2026, month: 4, day: 30, hour: 15)) ?? now.addingTimeInterval(3600)
        return CalendarEvent(id: "preview-work", title: "Alex 1:1", calendarID: "work", calendarName: "Work Calendar", accountName: "iCloud", startDate: start, endDate: start.addingTimeInterval(3600), isAllDay: false, location: "Conference Room", notes: nil, isRecurring: true, calendarColorHex: "#0A84FF")
    }

    static var deleteConfirmationContext: ConfirmationContext {
        ConfirmationContext(operation: .delete, title: "Delete Event?", message: "This removes the event from your calendar. Review before continuing.", before: workEvent, afterDraft: nil, patch: nil, targetEventID: workEvent.id, recurrenceScope: .thisEvent)
    }
}
