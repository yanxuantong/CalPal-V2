import XCTest
@testable import CalPal

final class PreferenceSummaryStoreTests: XCTestCase {
    func testAccountSeparatedSummariesAndReset() {
        let store = InMemoryPreferenceSummaryStore()
        store.save(PreferenceSummary(accountID: "icloud", preferredCalendarID: "work", commonHours: [9, 15], updatedAt: .now))
        store.save(PreferenceSummary(accountID: "google", preferredCalendarID: "personal", commonHours: [10], updatedAt: .now))
        XCTAssertEqual(store.load(accountID: "icloud")?.preferredCalendarID, "work")
        store.reset(accountID: "icloud")
        XCTAssertNil(store.load(accountID: "icloud"))
        XCTAssertNotNil(store.load(accountID: "google"))
        store.reset(accountID: nil)
        XCTAssertNil(store.load(accountID: "google"))
    }

    func testProductionDiagnosticsSnapshotSummarizesLocalCountsOnly() {
        let store = InMemoryProductionDiagnosticsStore()

        store.record(.commandSubmitted)
        store.record(.commandSucceeded)
        store.record(.foundationModelsFallback)
        store.record(.calendarAccessDenied)

        let snapshot = store.snapshot()

        XCTAssertEqual(snapshot.totalCommands, 1)
        XCTAssertEqual(snapshot.successfulCommands, 1)
        XCTAssertEqual(snapshot.failedCommands, 0)
        XCTAssertEqual(snapshot.count(.foundationModelsFallback), 1)
        XCTAssertEqual(snapshot.count(.calendarAccessDenied), 1)
        XCTAssertEqual(snapshot.resultSummary, "1 succeeded, 0 failed, 1 submitted")
        XCTAssertEqual(snapshot.aiRouteSummary, "0 Apple Intelligence, 1 local fallback")
        XCTAssertEqual(snapshot.releaseRiskSummary, "1 permission or availability blocker(s) recorded locally")
    }

    func testUserDefaultsProductionDiagnosticsCanResetWithoutTouchingPreferences() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let diagnostics = UserDefaultsProductionDiagnosticsStore(defaults: defaults)
        let prefs = UserDefaultsPreferenceSummaryStore(defaults: defaults)

        prefs.saveDefaultCalendarID("work")
        diagnostics.record(.commandSubmitted)
        diagnostics.record(.commandFailed)

        XCTAssertEqual(diagnostics.snapshot().totalCommands, 1)
        diagnostics.reset()

        XCTAssertEqual(diagnostics.snapshot().totalCommands, 0)
        XCTAssertEqual(prefs.loadDefaultCalendarID(), "work")
    }

    func testRemoteAIExplicitOptInPolicyRequiresEndpointAndUploadConsent() throws {
        let endpoint = try XCTUnwrap(URL(string: "https://api.example.test/calendar/parse"))

        XCTAssertFalse(RemoteCalendarAIPolicy.localOnly.canSendRequests)
        XCTAssertFalse(RemoteCalendarAIPolicy(isEnabled: true, endpoint: endpoint, allowsCommandTextUpload: false).canSendRequests)
        XCTAssertTrue(RemoteCalendarAIPolicy.explicitOptIn(endpoint: endpoint).canSendRequests)
    }

    func testAppStorePrivacyConfigurationKeepsProductionLocalOnly() {
        let configuration = ProductionPrivacyConfiguration.appStoreLocalOnly

        XCTAssertEqual(configuration.remoteAIPolicy, .localOnly)
        XCTAssertTrue(configuration.keepsCommandTextOnDevice)
        XCTAssertFalse(configuration.allowsTelemetryExport)
        XCTAssertTrue(configuration.releaseSummary.contains("disabled"))
        XCTAssertTrue(configuration.telemetrySummary.contains("disabled"))
    }
}
