import XCTest
import SwiftUI
import UIKit
@testable import CalPal

final class CalendarMutationPolicyTests: XCTestCase {
    func testHighConfidenceCreateAutoApplies() async {
        let repo = MockCalendarRepository()
        let calendars: [CalendarInfo]
        do {
            calendars = try await repo.fetchCalendars()
        } catch {
            return XCTFail("Expected mock calendars: \(error)")
        }
        let now = PreviewFixtures.now
        let draft = EventDraft(title: "Meeting", startDate: now.addingTimeInterval(3600), endDate: now.addingTimeInterval(7200), calendarID: nil, calendarName: nil, location: nil, notes: nil)
        let parsed = ParsedCalendarCommand(originalText: "Meeting", localeIdentifier: "en-US", intent: .create(draft), confidence: 0.9, missingFields: [], warnings: [])
        let decision = await CalendarMutationPolicy(now: { now }).decide(parsed: parsed, calendars: calendars, repository: repo)
        guard case .autoApply(let result) = decision else { return XCTFail("Expected auto apply") }
        XCTAssertEqual(result.calendarID, "work")
    }

    func testLowConfidenceCreateNeedsCorrection() async {
        let repo = MockCalendarRepository()
        let calendars: [CalendarInfo]
        do {
            calendars = try await repo.fetchCalendars()
        } catch {
            return XCTFail("Expected mock calendars: \(error)")
        }
        let now = PreviewFixtures.now
        let draft = EventDraft(title: "", startDate: now, endDate: now.addingTimeInterval(3600), calendarID: nil, calendarName: nil, location: nil, notes: nil)
        let parsed = ParsedCalendarCommand(originalText: "something", localeIdentifier: "en-US", intent: .create(draft), confidence: 0.4, missingFields: ["title"], warnings: [])
        let decision = await CalendarMutationPolicy(now: { now }).decide(parsed: parsed, calendars: calendars, repository: repo)
        guard case .needsCorrection = decision else { return XCTFail("Expected correction") }
    }

    func testDeleteNeedsConfirmationForSingleCandidate() async {
        let repo = MockCalendarRepository()
        let parsed = ParsedCalendarCommand(originalText: "delete Alex", localeIdentifier: "en-US", intent: .delete(query: EventQuery(phrase: "delete Alex", day: PreviewFixtures.now, titleHint: "Alex")), confidence: 0.9, missingFields: [], warnings: [])
        let decision = await CalendarMutationPolicy(now: { PreviewFixtures.now }).decide(parsed: parsed, calendars: [], repository: repo)
        guard case .needsConfirmation(let context) = decision else { return XCTFail("Expected confirmation") }
        XCTAssertEqual(context.operation, .delete)
        XCTAssertTrue(context.isDestructive)
        XCTAssertEqual(context.recurrenceScope, .thisEvent)
    }
}

final class LightDarkUIPresentationTests: XCTestCase {
    func testAgendaNowPlacementOnlyShowsForTodayAndSplitsUpcomingEvents() {
        let calendar = Calendar(identifier: .gregorian)
        let day = calendar.date(from: DateComponents(year: 2026, month: 5, day: 1))!
        let now = calendar.date(from: DateComponents(year: 2026, month: 5, day: 1, hour: 12))!
        let past = CalendarEvent(id: "past", title: "Past", calendarID: "work", calendarName: "Work", accountName: "iCloud", startDate: now.addingTimeInterval(-3600), endDate: now.addingTimeInterval(-1800), isAllDay: false, location: nil, notes: nil, isRecurring: false, calendarColorHex: "#0A84FF")
        let future = CalendarEvent(id: "future", title: "Future", calendarID: "personal", calendarName: "Personal", accountName: "iCloud", startDate: now.addingTimeInterval(3600), endDate: now.addingTimeInterval(7200), isAllDay: false, location: nil, notes: nil, isRecurring: false, calendarColorHex: nil)

        let todaySections = AgendaNowPlacement.sections(events: [future, past], selectedDay: day, now: now, calendar: calendar)
        XCTAssertTrue(todaySections.showsNow)
        XCTAssertEqual(todaySections.earlier.map(\.id), ["past"])
        XCTAssertEqual(todaySections.upcoming.map(\.id), ["future"])

        let tomorrow = calendar.date(byAdding: .day, value: 1, to: day)!
        let tomorrowSections = AgendaNowPlacement.sections(events: [future, past], selectedDay: tomorrow, now: now, calendar: calendar)
        XCTAssertFalse(tomorrowSections.showsNow)
        XCTAssertEqual(tomorrowSections.earlier.map(\.id), ["past", "future"])
        XCTAssertTrue(tomorrowSections.upcoming.isEmpty)
    }

    func testMockCalendarEventsCarryCalendarColorHex() async throws {
        let repo = MockCalendarRepository()
        let events = try await repo.fetchEvents(for: PreviewFixtures.now)
        XCTAssertEqual(events.first(where: { $0.id == "standup" })?.calendarColorHex, "#0A84FF")
        XCTAssertEqual(events.first(where: { $0.id == "focus" })?.calendarColorHex, "#30D158")
    }
}


@MainActor
final class VisualSnapshotRenderingTests: XCTestCase {
    func testAppIconAssetIsProductionReadyAndSizeChecked() throws {
        let root = sourceRoot()
        let iconURL = root.appendingPathComponent("CalPal/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png")
        let contentsURL = root.appendingPathComponent("CalPal/Assets.xcassets/AppIcon.appiconset/Contents.json")
        let contentsData = try Data(contentsOf: contentsURL)
        let contentsText = String(decoding: contentsData, as: UTF8.self)
        XCTAssertTrue(contentsText.contains("AppIcon-1024.png"))
        XCTAssertTrue(contentsText.contains("1024x1024"))

        let image = try XCTUnwrap(UIImage(contentsOfFile: iconURL.path))
        XCTAssertEqual(Int(image.size.width), 1024)
        XCTAssertEqual(Int(image.size.height), 1024)
        XCTAssertGreaterThan(try pngByteCount(for: image, resizedTo: CGSize(width: 29, height: 29)), 900)
        XCTAssertGreaterThan(try pngByteCount(for: image, resizedTo: CGSize(width: 40, height: 40)), 1_200)
        XCTAssertGreaterThan(try pngByteCount(for: image, resizedTo: CGSize(width: 60, height: 60)), 1_800)
        XCTAssertGreaterThan(try Data(contentsOf: iconURL).count, 50_000)
    }

    func testCoreSwiftUISurfacesRenderVisualSnapshotsInLightAndDark() async throws {
        let app = AppModel(dependencies: .mock(), defaults: UserDefaults(suiteName: UUID().uuidString)!)
        app.commandHomeModel.agendaState = .loaded
        app.commandHomeModel.events = try await MockCalendarRepository().fetchEvents(for: PreviewFixtures.now)
        app.commandHomeModel.selectedDay = PreviewFixtures.now

        let homeLight = render(
            NavigationStack { CommandHomeView().environmentObject(app).environmentObject(app.commandHomeModel) },
            colorScheme: .light,
            size: CGSize(width: 390, height: 844)
        )
        let homeDark = render(
            NavigationStack { CommandHomeView().environmentObject(app).environmentObject(app.commandHomeModel) },
            colorScheme: .dark,
            size: CGSize(width: 390, height: 844)
        )
        let textEntryDark = render(TextEntryView { _ in }, colorScheme: .dark, size: CGSize(width: 390, height: 520))
        let confirmationLight = render(ConfirmationView(context: PreviewFixtures.deleteConfirmationContext) { _ in }, colorScheme: .light, size: CGSize(width: 390, height: 620))
        let settingsDark = render(SettingsView(startSection: nil).environmentObject(app), colorScheme: .dark, size: CGSize(width: 390, height: 720))
        let unavailableLight = render(
            UnavailableView(context: UnavailableContext(title: "Speech Unavailable", message: "Text entry and manual create remain available.", primaryAction: .openTextEntry, secondaryAction: .openManualCreate)) { _ in },
            colorScheme: .light,
            size: CGSize(width: 390, height: 520)
        )

        assertSnapshot(homeLight, size: CGSize(width: 390, height: 844))
        assertSnapshot(homeDark, size: CGSize(width: 390, height: 844))
        assertSnapshot(textEntryDark, size: CGSize(width: 390, height: 520))
        assertSnapshot(confirmationLight, size: CGSize(width: 390, height: 620))
        assertSnapshot(settingsDark, size: CGSize(width: 390, height: 720))
        assertSnapshot(unavailableLight, size: CGSize(width: 390, height: 520))
        XCTAssertGreaterThan(averageLuminance(homeLight) - averageLuminance(homeDark), 0.10)
    }

    func testCommandOrbSnapshotsCaptureIdleAndRecordingStates() throws {
        let idle = render(CommandOrb(state: .idle, reduceMotion: true, showsIdleHint: true, onRecordingStart: {}, onRecordingFinish: {}, onDoubleTap: {}, onCancel: {}), colorScheme: .light, size: CGSize(width: 240, height: 180))
        let recording = render(CommandOrb(state: .recording(startedAt: Date()), reduceMotion: true, showsIdleHint: true, onRecordingStart: {}, onRecordingFinish: {}, onDoubleTap: {}, onCancel: {}), colorScheme: .light, size: CGSize(width: 240, height: 180))

        XCTAssertGreaterThan(try XCTUnwrap(idle.pngData()).count, 4_000)
        XCTAssertGreaterThan(try XCTUnwrap(recording.pngData()).count, 4_000)
        XCTAssertGreaterThan(colorDistance(centerColor(recording), centerColor(idle)), 0.15)
    }

    private func assertSnapshot(_ image: UIImage, size: CGSize, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(Int(image.size.width), Int(size.width), file: file, line: line)
        XCTAssertEqual(Int(image.size.height), Int(size.height), file: file, line: line)
        XCTAssertGreaterThan(image.pngData()?.count ?? 0, 8_000, file: file, line: line)
    }

    private func render<V: View>(_ view: V, colorScheme: ColorScheme, size: CGSize) -> UIImage {
        let controller = UIHostingController(rootView: view.environment(\.colorScheme, colorScheme))
        controller.view.bounds = CGRect(origin: .zero, size: size)
        controller.view.backgroundColor = .clear
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.rootViewController = controller
        window.makeKeyAndVisible()
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }
    }

    private func sourceRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func pngByteCount(for image: UIImage, resizedTo size: CGSize) throws -> Int {
        let renderer = UIGraphicsImageRenderer(size: size)
        let resized = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
        return try XCTUnwrap(resized.pngData()).count
    }

    private func averageLuminance(_ image: UIImage) -> CGFloat {
        let color = centerColor(image, sampleWholeImage: true)
        return 0.2126 * color.red + 0.7152 * color.green + 0.0722 * color.blue
    }

    private func centerColor(_ image: UIImage, sampleWholeImage: Bool = false) -> (red: CGFloat, green: CGFloat, blue: CGFloat) {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1))
        let sampled = renderer.image { _ in
            if sampleWholeImage {
                image.draw(in: CGRect(origin: .zero, size: CGSize(width: 1, height: 1)))
            } else {
                let sx = image.size.width / 2 - 0.5
                let sy = image.size.height / 2 - 0.5
                image.draw(at: CGPoint(x: -sx, y: -sy))
            }
        }
        guard let cgImage = sampled.cgImage,
              let provider = cgImage.dataProvider,
              let data = provider.data,
              let bytes = CFDataGetBytePtr(data) else { return (0, 0, 0) }
        return (CGFloat(bytes[0]) / 255, CGFloat(bytes[1]) / 255, CGFloat(bytes[2]) / 255)
    }

    private func colorDistance(_ lhs: (red: CGFloat, green: CGFloat, blue: CGFloat), _ rhs: (red: CGFloat, green: CGFloat, blue: CGFloat)) -> CGFloat {
        sqrt(pow(lhs.red - rhs.red, 2) + pow(lhs.green - rhs.green, 2) + pow(lhs.blue - rhs.blue, 2))
    }
}


@MainActor
final class MVPBugFixRegressionTests: XCTestCase {
    func testHoldToTalkDoesNotFinishUntilExplicitRelease() async throws {
        let repo = MockCalendarRepository()
        let speech = MockSpeechService(transcript: "Meeting with Alex tomorrow at 9 am")
        let prefs = InMemoryPreferenceSummaryStore()
        let parser = NaturalLanguageCalendarParser(now: { PreviewFixtures.now })
        let policy = CalendarMutationPolicy(now: { PreviewFixtures.now }, preferredCalendarID: { prefs.loadDefaultCalendarID() })
        let pipeline = CalendarCommandPipeline(parser: parser, policy: policy, repository: repo)
        let dependencies = DependencyContainer(calendarRepository: repo, commandPipeline: pipeline, speechService: speech, modelProvider: MockModelProvider(), preferenceSummaryStore: prefs, capabilityService: DefaultCapabilityService(calendarRepository: repo, speechService: speech, modelProvider: MockModelProvider()))
        let model = CommandHomeModel(dependencies: dependencies, selectedDay: PreviewFixtures.now)

        model.beginRecording()
        try await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(speech.startTranscriptionCount, 1)
        XCTAssertEqual(speech.finishTranscriptionCount, 0, "Recording must not finish before explicit release.")

        model.finishRecording()
        model.finishRecording()
        try await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertEqual(speech.finishTranscriptionCount, 1, "Duplicate release/end events must finish at most once.")
        XCTAssertEqual(repo.createdDrafts.count, 1)
    }

    func testInitialPermissionInitializationRequestsSpeechAndCalendarOnce() async throws {
        let repo = MockCalendarRepository()
        let speech = MockSpeechService()
        let prefs = InMemoryPreferenceSummaryStore()
        let dependencies = DependencyContainer(
            calendarRepository: repo,
            commandPipeline: CalendarCommandPipeline(parser: NaturalLanguageCalendarParser(now: { PreviewFixtures.now }), policy: CalendarMutationPolicy(now: { PreviewFixtures.now }), repository: repo),
            speechService: speech,
            modelProvider: MockModelProvider(),
            preferenceSummaryStore: prefs,
            capabilityService: DefaultCapabilityService(calendarRepository: repo, speechService: speech, modelProvider: MockModelProvider())
        )
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let app = AppModel(dependencies: dependencies, defaults: defaults)

        await app.initializeRequiredPermissionsIfNeeded()
        await app.initializeRequiredPermissionsIfNeeded()

        XCTAssertEqual(speech.requestAuthorizationCount, 1)
        XCTAssertEqual(repo.requestFullAccessCount, 1)
        XCTAssertEqual(app.capabilitySummary.calendar, .allowed)
    }

    func testDefaultCalendarPreferenceDrivesAutoReviewWriteTarget() async throws {
        let repo = MockCalendarRepository()
        let prefs = InMemoryPreferenceSummaryStore()
        prefs.saveDefaultCalendarID("personal")
        let parser = NaturalLanguageCalendarParser(now: { PreviewFixtures.now })
        let policy = CalendarMutationPolicy(now: { PreviewFixtures.now }, preferredCalendarID: { prefs.loadDefaultCalendarID() })
        let pipeline = CalendarCommandPipeline(parser: parser, policy: policy, repository: repo)

        let output = await pipeline.process(text: "Standup tomorrow at 9 am")
        guard case .result(let result) = output else { return XCTFail("Expected successful auto-apply result") }
        XCTAssertEqual(result.event?.calendarID, "personal")
        XCTAssertEqual(repo.createdDrafts.first?.calendarID, "personal")
    }

    func testNaturalLanguageParserUsesInjectedCurrentTimezone() throws {
        var losAngelesCalendar = Calendar(identifier: .gregorian)
        let losAngeles = TimeZone(identifier: "America/Los_Angeles")!
        losAngelesCalendar.timeZone = losAngeles
        let now = losAngelesCalendar.date(from: DateComponents(year: 2026, month: 5, day: 1, hour: 12))!
        let parser = NaturalLanguageCalendarParser(calendar: losAngelesCalendar, timeZone: losAngeles, now: { now })

        let parsed = parser.parse("Meeting tomorrow at 9 am")
        guard case .create(let draft) = parsed.intent else { return XCTFail("Expected create draft") }
        let components = losAngelesCalendar.dateComponents(in: losAngeles, from: draft.startDate)
        XCTAssertEqual(components.hour, 9)
        XCTAssertEqual(components.minute, 0)
        XCTAssertEqual(components.day, 2)
    }

    func testChineseAfternoonTimeUsesLocalTimezoneWallClock() throws {
        var losAngelesCalendar = Calendar(identifier: .gregorian)
        let losAngeles = TimeZone(identifier: "America/Los_Angeles")!
        losAngelesCalendar.timeZone = losAngeles
        let now = losAngelesCalendar.date(from: DateComponents(year: 2026, month: 5, day: 1, hour: 12))!
        let parser = NaturalLanguageCalendarParser(calendar: losAngelesCalendar, timeZone: losAngeles, now: { now })

        let parsed = parser.parse("明天下午三点和 Alex 开会")
        guard case .create(let draft) = parsed.intent else { return XCTFail("Expected create draft") }
        let components = losAngelesCalendar.dateComponents(in: losAngeles, from: draft.startDate)
        XCTAssertEqual(components.hour, 15)
        XCTAssertEqual(components.minute, 0)
        XCTAssertEqual(components.day, 2)
    }

    @MainActor
    func testCommandHintHidesAfterFirstCommandUse() {
        let model = CommandHomeModel(dependencies: .mock(), selectedDay: PreviewFixtures.now)
        XCTAssertTrue(model.showsCommandHint)
        model.hideCommandHint()
        XCTAssertFalse(model.showsCommandHint)
    }

    @MainActor
    func testResultTapFocusesAgendaOnResultEventDate() throws {
        let model = CommandHomeModel(dependencies: .mock(), selectedDay: PreviewFixtures.now)
        let targetDay = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: 2, to: PreviewFixtures.now))
        let event = CalendarEvent(
            id: "created-future-event",
            title: "Future review",
            calendarID: "work",
            calendarName: "Work Calendar",
            accountName: "iCloud",
            startDate: targetDay,
            endDate: targetDay.addingTimeInterval(3600),
            isAllDay: false,
            location: nil,
            notes: nil,
            isRecurring: false,
            calendarColorHex: "#0A84FF"
        )
        model.latestResult = CommandResultViewState(title: "Added to Calendar", message: "Future review", event: event, actionTitle: "Open in Calendar")

        model.focusLatestResultDate()

        XCTAssertNil(model.latestResult)
        XCTAssertTrue(Calendar.current.isDate(model.selectedDay, inSameDayAs: targetDay))
    }

    func testCommandOrbUsesStableSnapshotSizeAcrossIdleAndRecording() throws {
        let idle = render(CommandOrb(state: .idle, reduceMotion: true, showsIdleHint: true, onRecordingStart: {}, onRecordingFinish: {}, onDoubleTap: {}, onCancel: {}), colorScheme: .light, size: CGSize(width: 240, height: 220))
        let recording = render(CommandOrb(state: .recording(startedAt: Date()), reduceMotion: true, showsIdleHint: true, onRecordingStart: {}, onRecordingFinish: {}, onDoubleTap: {}, onCancel: {}), colorScheme: .light, size: CGSize(width: 240, height: 220))
        XCTAssertEqual(idle.size, recording.size)
        XCTAssertGreaterThan(try XCTUnwrap(recording.pngData()).count, 4_000)
    }

    func testDarkAppIconVariantIsConfigured() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let contentsURL = root.appendingPathComponent("CalPal/Assets.xcassets/AppIcon.appiconset/Contents.json")
        let darkURL = root.appendingPathComponent("CalPal/Assets.xcassets/AppIcon.appiconset/AppIcon-Dark-1024.png")
        let contents = String(decoding: try Data(contentsOf: contentsURL), as: UTF8.self)
        XCTAssertTrue(contents.contains("AppIcon-Dark-1024.png"))
        XCTAssertTrue(contents.contains("luminosity"))
        XCTAssertTrue(contents.contains("dark"))
        let darkImage = try XCTUnwrap(UIImage(contentsOfFile: darkURL.path))
        XCTAssertEqual(Int(darkImage.size.width), 1024)
        XCTAssertEqual(Int(darkImage.size.height), 1024)
        XCTAssertGreaterThan(try Data(contentsOf: darkURL).count, 10_000)
    }

    private func render<V: View>(_ view: V, colorScheme: ColorScheme, size: CGSize) -> UIImage {
        let controller = UIHostingController(rootView: view.environment(\.colorScheme, colorScheme))
        controller.view.bounds = CGRect(origin: .zero, size: size)
        controller.view.backgroundColor = .clear
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.rootViewController = controller
        window.makeKeyAndVisible()
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        return UIGraphicsImageRenderer(size: size).image { _ in
            controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }
    }
}
