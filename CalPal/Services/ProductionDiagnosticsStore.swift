import Foundation

enum ProductionDiagnosticEvent: String, CaseIterable, Codable, Hashable {
    case commandSubmitted
    case commandSucceeded
    case commandFailed
    case correctionShown
    case confirmationShown
    case candidateSelectionShown
    case unavailableShown
    case foundationModelsGenerated
    case foundationModelsFallback
    case calendarAccessDenied
    case speechDenied
}

struct ProductionDiagnosticsSnapshot: Equatable {
    var counts: [ProductionDiagnosticEvent: Int]
    var updatedAt: Date?

    func count(_ event: ProductionDiagnosticEvent) -> Int {
        counts[event, default: 0]
    }

    var totalCommands: Int { count(.commandSubmitted) }
    var successfulCommands: Int { count(.commandSucceeded) }
    var failedCommands: Int { count(.commandFailed) }

    var resultSummary: String {
        guard totalCommands > 0 else { return "No local command activity has been recorded on this device." }
        return "\(successfulCommands) succeeded, \(failedCommands) failed, \(totalCommands) submitted"
    }

    var aiRouteSummary: String {
        let generated = count(.foundationModelsGenerated)
        let fallback = count(.foundationModelsFallback)
        guard generated + fallback > 0 else { return "No AI route outcomes recorded yet." }
        return "\(generated) Apple Intelligence, \(fallback) local fallback"
    }

    var releaseRiskSummary: String {
        let attention = count(.calendarAccessDenied) + count(.speechDenied) + count(.unavailableShown)
        guard attention > 0 else { return "No local permission or availability blockers recorded." }
        return "\(attention) permission or availability blocker(s) recorded locally"
    }
}

protocol ProductionDiagnosticsStoreProtocol: AnyObject {
    func record(_ event: ProductionDiagnosticEvent)
    func snapshot() -> ProductionDiagnosticsSnapshot
    func reset()
}

final class UserDefaultsProductionDiagnosticsStore: ProductionDiagnosticsStoreProtocol {
    private let defaults: UserDefaults
    private let countsKey = "calpal.productionDiagnostics.counts"
    private let updatedAtKey = "calpal.productionDiagnostics.updatedAt"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func record(_ event: ProductionDiagnosticEvent) {
        var counts = storedCounts()
        counts[event.rawValue, default: 0] += 1
        defaults.set(counts, forKey: countsKey)
        defaults.set(Date(), forKey: updatedAtKey)
    }

    func snapshot() -> ProductionDiagnosticsSnapshot {
        let counts = storedCounts().reduce(into: [ProductionDiagnosticEvent: Int]()) { result, pair in
            guard let event = ProductionDiagnosticEvent(rawValue: pair.key) else { return }
            result[event] = pair.value
        }
        return ProductionDiagnosticsSnapshot(counts: counts, updatedAt: defaults.object(forKey: updatedAtKey) as? Date)
    }

    func reset() {
        defaults.removeObject(forKey: countsKey)
        defaults.removeObject(forKey: updatedAtKey)
    }

    private func storedCounts() -> [String: Int] {
        defaults.dictionary(forKey: countsKey) as? [String: Int] ?? [:]
    }
}

final class InMemoryProductionDiagnosticsStore: ProductionDiagnosticsStoreProtocol {
    private var counts: [ProductionDiagnosticEvent: Int] = [:]
    private var updatedAt: Date?

    func record(_ event: ProductionDiagnosticEvent) {
        counts[event, default: 0] += 1
        updatedAt = Date()
    }

    func snapshot() -> ProductionDiagnosticsSnapshot {
        ProductionDiagnosticsSnapshot(counts: counts, updatedAt: updatedAt)
    }

    func reset() {
        counts.removeAll()
        updatedAt = nil
    }
}
