import Foundation

struct CalendarInfo: Identifiable, Equatable, Codable, Hashable {
    var id: String
    var title: String
    var accountName: String
    var allowsContentModifications: Bool
    var colorHex: String?

    var subtitle: String { "\(accountName) · \(allowsContentModifications ? "writable" : "read-only")" }
}

struct CalendarEvent: Identifiable, Equatable, Codable, Hashable {
    var id: String
    var title: String
    var calendarID: String
    var calendarName: String
    var accountName: String
    var startDate: Date
    var endDate: Date
    var isAllDay: Bool
    var location: String?
    var notes: String?
    var isRecurring: Bool
    var calendarColorHex: String? = nil
}

struct EventDraft: Identifiable, Equatable, Codable, Hashable {
    var id = UUID()
    var title: String
    var startDate: Date
    var endDate: Date
    var calendarID: String?
    var calendarName: String?
    var location: String?
    var notes: String?
    var isAllDay: Bool = false

    var hasRequiredFields: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && endDate > startDate
    }

    var targetCalendarSummary: String {
        calendarName ?? "Default writable calendar"
    }
}

struct EventPatch: Equatable, Codable, Hashable {
    var title: String?
    var startDate: Date?
    var endDate: Date?
    var location: String?
    var notes: String?
}

enum RecurrenceChangeScope: String, CaseIterable, Identifiable, Codable, Hashable {
    case thisEvent = "This event only"
    case futureEvents = "This and future events"

    var id: String { rawValue }
}

struct EventQuery: Equatable, Codable, Hashable {
    var phrase: String
    var day: Date?
    var titleHint: String?
    var boundedDays: Int = 14
}

enum CalendarDeepLink {
    static func appleCalendarURL(for date: Date) -> URL? {
        URL(string: "calshow:\(date.timeIntervalSinceReferenceDate)")
    }
}
