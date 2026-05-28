import Foundation

struct CalendarInfo: Identifiable, Equatable, Codable, Hashable {
    var id: String
    var title: String
    var accountName: String
    var allowsContentModifications: Bool
    var colorHex: String?

    var subtitle: String { "\(accountName) · \(allowsContentModifications ? "writable" : "read-only")" }
    var targetSummary: String { "\(title) · \(accountName)" }
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

    var calendarAccountSummary: String {
        "\(calendarName) · \(accountName)"
    }
}

struct EventDraft: Identifiable, Equatable, Codable, Hashable {
    var id = UUID()
    var title: String
    var startDate: Date
    var endDate: Date
    var calendarID: String?
    var calendarName: String?
    var calendarAccountName: String?
    var location: String?
    var notes: String?
    var isAllDay: Bool = false

    init(
        id: UUID = UUID(),
        title: String,
        startDate: Date,
        endDate: Date,
        calendarID: String?,
        calendarName: String?,
        calendarAccountName: String? = nil,
        location: String?,
        notes: String?,
        isAllDay: Bool = false
    ) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.calendarID = calendarID
        self.calendarName = calendarName
        self.calendarAccountName = calendarAccountName
        self.location = location
        self.notes = notes
        self.isAllDay = isAllDay
    }

    var hasRequiredFields: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && endDate > startDate
    }

    var targetCalendarSummary: String {
        guard let calendarName else { return "Default writable calendar" }
        guard let calendarAccountName, !calendarAccountName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return calendarName
        }
        return "\(calendarName) · \(calendarAccountName)"
    }

    var normalizedForSave: EventDraft {
        var copy = self
        copy.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.location = location?.nilIfBlank
        copy.notes = notes?.nilIfBlank
        return copy
    }
}

struct EventPatch: Equatable, Codable, Hashable {
    var title: String?
    var startDate: Date?
    var endDate: Date?
    var location: String?
    var notes: String?

    var hasChanges: Bool {
        title != nil || startDate != nil || endDate != nil || location != nil || notes != nil
    }

    var normalizedForSave: EventPatch {
        EventPatch(
            title: title?.nilIfBlank,
            startDate: startDate,
            endDate: endDate,
            location: location?.trimmedForPatch,
            notes: notes?.trimmedForPatch
        )
    }
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

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var trimmedForPatch: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
