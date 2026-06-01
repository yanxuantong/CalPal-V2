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

    func testChineseWorkoutTonightAtTenForOneHour() {
        let parsed = parser.parse("我想要在今天晚上 10 点钟 workout 做一个小时")
        guard case .create(let draft) = parsed.intent else { return XCTFail("Expected create") }
        XCTAssertEqual(draft.title, "workout")
        XCTAssertTrue(Calendar.current.isDate(draft.startDate, inSameDayAs: now))
        XCTAssertEqual(Calendar.current.component(.hour, from: draft.startDate), 22)
        XCTAssertEqual(Calendar.current.component(.minute, from: draft.startDate), 0)
        XCTAssertEqual(draft.endDate.timeIntervalSince(draft.startDate), 3600)
        XCTAssertTrue(parsed.missingFields.isEmpty)
    }

    func testEnglishWorkoutTonightAtTenForOneHour() {
        let parsed = parser.parse("I want to schedule workout today at 10 pm for one hour")
        guard case .create(let draft) = parsed.intent else { return XCTFail("Expected create") }
        XCTAssertEqual(draft.title, "workout")
        XCTAssertTrue(Calendar.current.isDate(draft.startDate, inSameDayAs: now))
        XCTAssertEqual(Calendar.current.component(.hour, from: draft.startDate), 22)
        XCTAssertEqual(Calendar.current.component(.minute, from: draft.startDate), 0)
        XCTAssertEqual(draft.endDate.timeIntervalSince(draft.startDate), 3600)
        XCTAssertTrue(parsed.missingFields.isEmpty)
    }

    func testFoundationModelsParserPrefersModelResultOverFallbackDate() async throws {
        let modelStart = try XCTUnwrap(Calendar.current.date(from: DateComponents(year: 2026, month: 4, day: 30, hour: 21)))
        let modelEnd = modelStart.addingTimeInterval(3600)
        let fallback = NaturalLanguageCalendarParser(now: { self.now })
        let parser = FoundationModelsCalendarParser(
            fallback: fallback,
            modelProvider: MockModelProvider(),
            now: { self.now },
            commandGenerator: { text, _, _, includesChinese in
                XCTAssertEqual(text, "I want to schedule workout today at 10 pm for one hour")
                XCTAssertFalse(includesChinese)
                let draft = EventDraft(title: "AI workout", startDate: modelStart, endDate: modelEnd, calendarID: nil, calendarName: nil, location: nil, notes: nil)
                return ParsedCalendarCommand(originalText: text, localeIdentifier: "en-US", intent: .create(draft), confidence: 0.93, missingFields: [], warnings: [])
            }
        )

        let parsed = await parser.parseCommand("I want to schedule workout today at 10 pm for one hour")
        guard case .create(let draft) = parsed.intent else { return XCTFail("Expected create") }
        XCTAssertEqual(draft.title, "AI workout")
        XCTAssertEqual(Calendar.current.component(.hour, from: draft.startDate), 21)
        XCTAssertEqual(parsed.confidence, 0.93)
        XCTAssertTrue(parsed.missingFields.isEmpty)
        XCTAssertEqual(parsed.parseRoute, .foundationModelsGenerated)
    }

    func testFoundationModelsParserMarksUnavailableFallbackRoute() async {
        let parser = FoundationModelsCalendarParser(
            fallback: NaturalLanguageCalendarParser(now: { self.now }),
            modelProvider: FixedModelProvider(status: .unavailable),
            now: { self.now }
        )

        let parsed = await parser.parseCommand("Meeting with Alex tomorrow at 3 PM")

        XCTAssertEqual(parsed.parseRoute, .foundationModelsUnavailable)
    }

    func testFoundationModelsParserMarksFailedFallbackRoute() async {
        enum TestGenerationError: Error { case failed }
        let parser = FoundationModelsCalendarParser(
            fallback: NaturalLanguageCalendarParser(now: { self.now }),
            modelProvider: MockModelProvider(),
            now: { self.now },
            commandGenerator: { _, _, _, _ in throw TestGenerationError.failed }
        )

        let parsed = await parser.parseCommand("Meeting with Alex tomorrow at 3 PM")

        XCTAssertEqual(parsed.parseRoute, .foundationModelsFailedOver)
    }

    func testRemoteAIParserDoesNotCallClientWhenPolicyIsLocalOnly() async {
        let client = RecordingRemoteCalendarAIClient()
        let parser = RemoteCalendarAIParser(
            fallback: NaturalLanguageCalendarParser(now: { self.now }),
            client: client,
            policy: .localOnly,
            now: { self.now }
        )

        let parsed = await parser.parseCommand("Meeting with Alex tomorrow at 3 PM")

        XCTAssertTrue(client.requests.isEmpty)
        XCTAssertEqual(parsed.parseRoute, .deterministicFallback)
        guard case .create = parsed.intent else { return XCTFail("Expected local fallback create") }
    }

    func testRemoteAIParserRequiresExplicitTextUploadPermission() async throws {
        let client = RecordingRemoteCalendarAIClient()
        let endpoint = try XCTUnwrap(URL(string: "https://api.example.test/calendar/parse"))
        let parser = RemoteCalendarAIParser(
            fallback: NaturalLanguageCalendarParser(now: { self.now }),
            client: client,
            policy: RemoteCalendarAIPolicy(isEnabled: true, endpoint: endpoint, allowsCommandTextUpload: false),
            now: { self.now }
        )

        let parsed = await parser.parseCommand("Meeting with Alex tomorrow at 3 PM")

        XCTAssertTrue(client.requests.isEmpty)
        XCTAssertEqual(parsed.parseRoute, .remoteAIFailedOver)
    }

    func testRemoteAIParserSendsExplicitOptInRequestAndMarksRemoteRoute() async throws {
        let client = RecordingRemoteCalendarAIClient()
        let endpoint = try XCTUnwrap(URL(string: "https://api.example.test/calendar/parse"))
        let remoteStart = try XCTUnwrap(Calendar.current.date(from: DateComponents(year: 2026, month: 5, day: 1, hour: 11)))
        let remoteDraft = EventDraft(title: "Remote parsed meeting", startDate: remoteStart, endDate: remoteStart.addingTimeInterval(1800), calendarID: nil, calendarName: nil, location: nil, notes: nil)
        client.response = RemoteCalendarAIResponse(parsedCommand: ParsedCalendarCommand(originalText: "remote", localeIdentifier: "en-US", intent: .create(remoteDraft), confidence: 0.91, missingFields: [], warnings: []))
        let parser = RemoteCalendarAIParser(
            fallback: NaturalLanguageCalendarParser(now: { self.now }),
            client: client,
            policy: .explicitOptIn(endpoint: endpoint),
            localeIdentifier: { "en-US" },
            timeZone: TimeZone(identifier: "America/Los_Angeles")!,
            now: { self.now }
        )

        let parsed = await parser.parseCommand("Meeting with Alex tomorrow at 3 PM")

        XCTAssertEqual(client.requests.count, 1)
        XCTAssertEqual(client.requests.first?.commandText, "Meeting with Alex tomorrow at 3 PM")
        XCTAssertEqual(client.requests.first?.localeIdentifier, "en-US")
        XCTAssertEqual(client.requests.first?.timeZoneIdentifier, "America/Los_Angeles")
        XCTAssertEqual(parsed.parseRoute, .remoteAIGenerated)
        guard case .create(let draft) = parsed.intent else { return XCTFail("Expected remote create") }
        XCTAssertEqual(draft.title, "Remote parsed meeting")
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

    func testV3ReadinessNaturalLanguageSampleSet() throws {
        let cases: [(text: String, dayOffset: Int, hour: Int, minute: Int, duration: TimeInterval)] = [
            ("Schedule design review day after tomorrow at 10am for 2 hours", 2, 10, 0, 7200),
            ("Coffee next Monday at noon", 4, 12, 0, 3600),
            ("Plan focus block Friday at 2 pm for 90 min", 1, 14, 0, 5400),
            ("Review launch checklist tomorrow at 11:30", 1, 11, 30, 3600),
            ("Schedule standup today at 9am for 30 min", 0, 9, 0, 1800),
            ("后天上午十点复盘", 2, 10, 0, 3600),
            ("下周一下午三点团队同步", 11, 15, 0, 3600),
            ("明天中午和 Alex 吃饭", 1, 12, 0, 3600),
            ("今天晚上八点健身两个小时", 0, 20, 0, 7200),
            ("周五下午四点半产品评审", 1, 16, 30, 3600)
        ]

        for item in cases {
            let parsed = parser.parse(item.text)
            guard case .create(let draft) = parsed.intent else { return XCTFail("Expected create for \(item.text)") }
            let expectedDay = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: item.dayOffset, to: Calendar.current.startOfDay(for: now)))
            XCTAssertTrue(Calendar.current.isDate(draft.startDate, inSameDayAs: expectedDay), item.text)
            XCTAssertEqual(Calendar.current.component(.hour, from: draft.startDate), item.hour, item.text)
            XCTAssertEqual(Calendar.current.component(.minute, from: draft.startDate), item.minute, item.text)
            XCTAssertEqual(draft.endDate.timeIntervalSince(draft.startDate), item.duration, item.text)
            XCTAssertTrue(parsed.missingFields.isEmpty, item.text)
        }
    }
}

private struct FixedModelProvider: ModelProviderProtocol {
    var status: PermissionStatus

    func availability() -> PermissionStatus {
        status
    }
}

private final class RecordingRemoteCalendarAIClient: RemoteCalendarAIClientProtocol {
    private(set) var requests: [RemoteCalendarAIRequest] = []
    var response: RemoteCalendarAIResponse?
    var error: Error?

    func parse(_ request: RemoteCalendarAIRequest, endpoint: URL) async throws -> RemoteCalendarAIResponse {
        requests.append(request)
        if let error { throw error }
        guard let response else { throw RemoteCalendarAIError.disabled }
        return response
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
