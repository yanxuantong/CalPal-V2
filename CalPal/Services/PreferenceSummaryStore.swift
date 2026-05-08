import Foundation

struct PreferenceSummary: Codable, Equatable {
    var accountID: String
    var preferredCalendarID: String?
    var commonHours: [Int]
    var updatedAt: Date
}

protocol PreferenceSummaryStoreProtocol {
    func load(accountID: String) -> PreferenceSummary?
    func save(_ summary: PreferenceSummary)
    func reset(accountID: String?)
    func loadDefaultCalendarID() -> String?
    func saveDefaultCalendarID(_ id: String?)
}

final class UserDefaultsPreferenceSummaryStore: PreferenceSummaryStoreProtocol {
    private let defaults: UserDefaults
    private let prefix = "calpal.preferenceSummary."
    private let defaultCalendarKey = "calpal.defaultCalendarID"
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    func load(accountID: String) -> PreferenceSummary? {
        guard let data = defaults.data(forKey: prefix + accountID) else { return nil }
        return try? JSONDecoder().decode(PreferenceSummary.self, from: data)
    }
    func save(_ summary: PreferenceSummary) {
        if let data = try? JSONEncoder().encode(summary) { defaults.set(data, forKey: prefix + summary.accountID) }
    }
    func reset(accountID: String?) {
        if let accountID { defaults.removeObject(forKey: prefix + accountID); return }
        defaults.dictionaryRepresentation().keys.filter { $0.hasPrefix(prefix) }.forEach(defaults.removeObject(forKey:))
        defaults.removeObject(forKey: defaultCalendarKey)
    }

    func loadDefaultCalendarID() -> String? { defaults.string(forKey: defaultCalendarKey) }

    func saveDefaultCalendarID(_ id: String?) {
        if let id { defaults.set(id, forKey: defaultCalendarKey) } else { defaults.removeObject(forKey: defaultCalendarKey) }
    }
}

final class InMemoryPreferenceSummaryStore: PreferenceSummaryStoreProtocol {
    private var storage: [String: PreferenceSummary] = [:]
    private var defaultCalendarID: String?
    func load(accountID: String) -> PreferenceSummary? { storage[accountID] }
    func save(_ summary: PreferenceSummary) { storage[summary.accountID] = summary }
    func reset(accountID: String?) {
        if let accountID { storage.removeValue(forKey: accountID) } else { storage.removeAll(); defaultCalendarID = nil }
    }
    func loadDefaultCalendarID() -> String? { defaultCalendarID }
    func saveDefaultCalendarID(_ id: String?) { defaultCalendarID = id }
}
