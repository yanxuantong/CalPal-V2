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
}
