import XCTest
@testable import CalPal

final class NaturalLanguageCalendarParserTests: XCTestCase {
    private var now: Date!
    private var parser: NaturalLanguageCalendarParser!

    override func setUp() {
        now = Calendar.current.date(from: DateComponents(year: 2026, month: 4, day: 30, hour: 12))!
        parser = NaturalLanguageCalendarParser(now: { self.now })
    }

    func testChineseCreateTomorrowAfternoon() {
        let parsed = parser.parse("明天下午三点和 Alex 开会")
        guard case .create(let draft) = parsed.intent else { return XCTFail("Expected create") }
        XCTAssertEqual(draft.title, "Meeting with Alex")
        XCTAssertTrue(parsed.isHighConfidence)
        XCTAssertEqual(Calendar.current.component(.hour, from: draft.startDate), 15)
    }

    func testEnglishCreateTomorrow() {
        let parsed = parser.parse("Meeting with Alex tomorrow at 3 PM")
        guard case .create(let draft) = parsed.intent else { return XCTFail("Expected create") }
        XCTAssertEqual(draft.title, "Meeting with Alex")
        XCTAssertEqual(Calendar.current.component(.hour, from: draft.startDate), 15)
    }

    func testCreateWithoutDateNeedsCorrection() {
        let parsed = parser.parse("Schedule a meeting")
        guard case .create = parsed.intent else { return XCTFail("Expected create") }
        XCTAssertTrue(parsed.missingFields.contains("time"))
        XCTAssertLessThan(parsed.confidence, 0.7)
    }

    func testExtremeFutureRequiresWarning() {
        let parsed = parser.parse("schedule something 100 years later at 9")
        XCTAssertFalse(parsed.warnings.isEmpty)
    }

    func testModifyRequiresConfirmationIntent() {
        let parsed = parser.parse("把明天下午和 Alex 的会改到四点")
        guard case .modify = parsed.intent else { return XCTFail("Expected modify") }
    }

    func testDeleteIntent() {
        let parsed = parser.parse("delete Alex meeting tomorrow")
        guard case .delete = parsed.intent else { return XCTFail("Expected delete") }
    }

    func testBilingualEvaluationCorpus() {
        let cases: [(String, CalendarCommandIntentMatcher, [String])] = [
            ("明天下午三点和 Alex 开会", .create, []),
            ("Schedule standup tomorrow at 9am", .create, []),
            ("把明天下午和 Alex 的会改到四点", .modify, []),
            ("delete Alex meeting tomorrow", .delete, []),
            ("Schedule a meeting", .create, ["time"]),
            ("schedule something 100 years later at 9", .create, ["date is outside the normal two-week window"])
        ]

        for (text, matcher, expectedSignals) in cases {
            let parsed = parser.parse(text)
            XCTAssertTrue(matcher.matches(parsed.intent), "Unexpected intent for \\(text)")
            for signal in expectedSignals {
                XCTAssertTrue((parsed.missingFields + parsed.warnings).contains(signal), "Missing signal \\(signal) for \\(text)")
            }
        }
    }
}

private enum CalendarCommandIntentMatcher {
    case create, modify, delete

    func matches(_ intent: CalendarCommandIntent?) -> Bool {
        switch (self, intent) {
        case (.create, .create), (.modify, .modify), (.delete, .delete):
            return true
        default:
            return false
        }
    }
}
