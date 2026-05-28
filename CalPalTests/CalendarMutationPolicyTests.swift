import XCTest
import SwiftUI
import UIKit
@testable import CalPal

final class CalendarMutationPolicyTests: XCTestCase {
    func testDemoRuntimeUsesMockDataAndSkipsBlockingLaunchPrompts() {
        let runtime = AppRuntimeConfiguration.current(arguments: ["CalPal", AppRuntimeConfiguration.demoLaunchArgument])

        XCTAssertTrue(runtime.skipsOnboarding)
        XCTAssertTrue(runtime.skipsPermissionRequests)
        XCTAssertTrue(runtime.preloadsAgenda)
        XCTAssertEqual(runtime.dependencies.calendarRepository.authorizationStatus(), .allowed)
        XCTAssertEqual(runtime.dependencies.speechService.authorizationStatus(), .allowed)
    }

    func testDemoRuntimeSeedsAgendaForLaunchDay() async throws {
        let runtime = AppRuntimeConfiguration.current(arguments: ["CalPal", AppRuntimeConfiguration.demoLaunchArgument])

        let events = try await runtime.dependencies.calendarRepository.fetchEvents(for: Date())

        XCTAssertFalse(events.isEmpty)
    }

    func testLiveRuntimeKeepsNormalPermissionFlow() {
        let runtime = AppRuntimeConfiguration.current(arguments: ["CalPal"])

        XCTAssertFalse(runtime.skipsOnboarding)
        XCTAssertFalse(runtime.skipsPermissionRequests)
        XCTAssertFalse(runtime.preloadsAgenda)
    }

    @MainActor
    func testDemoAppModelPreloadsAgendaWithoutShowingOnboarding() async {
        let launchDay = Date()
        let app = AppModel(
            runtime: .test(
                dependencies: .mock(now: launchDay),
                skipsOnboarding: true,
                skipsPermissionRequests: true,
                preloadsAgenda: true
            ),
            defaults: UserDefaults(suiteName: UUID().uuidString)!
        )

        app.presentOnboardingIfNeeded()
        await app.initializeRequiredPermissionsIfNeeded()

        XCTAssertNil(app.activeSheet)
        XCTAssertEqual(app.commandHomeModel.agendaState, .loaded)
        XCTAssertFalse(app.commandHomeModel.events.isEmpty)
    }

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
        let onboardingLight = render(OnboardingView(onContinue: {}), colorScheme: .light, size: CGSize(width: 390, height: 720))
        let correctionContext = CorrectionContext(
            title: "Review Event Details",
            message: "Some required details were missing or uncertain.",
            draft: EventDraft(title: "Launch review", startDate: PreviewFixtures.now, endDate: PreviewFixtures.now.addingTimeInterval(3600), calendarID: "work", calendarName: "Work Calendar", location: nil, notes: nil),
            missingFields: ["time"],
            sourceText: "Schedule launch review",
            parseRoute: .foundationModelsFailedOver
        )
        let correctionLight = render(CorrectionView(context: correctionContext) { _ in }, colorScheme: .light, size: CGSize(width: 390, height: 640))
        let confirmationLight = render(ConfirmationView(context: PreviewFixtures.deleteConfirmationContext) { _ in }, colorScheme: .light, size: CGSize(width: 390, height: 620))
        var routedConfirmation = PreviewFixtures.deleteConfirmationContext
        routedConfirmation.parseRoute = .foundationModelsFailedOver
        let routedConfirmationLight = render(ConfirmationView(context: routedConfirmation) { _ in }, colorScheme: .light, size: CGSize(width: 390, height: 660))
        let alternateCandidate = CalendarEvent(
            id: "candidate-alt",
            title: "Alex project sync",
            calendarID: "personal",
            calendarName: "Personal",
            accountName: "Google",
            startDate: PreviewFixtures.now.addingTimeInterval(7200),
            endDate: PreviewFixtures.now.addingTimeInterval(9000),
            isAllDay: false,
            location: nil,
            notes: nil,
            isRecurring: false,
            calendarColorHex: "#30D158"
        )
        let candidateContext = CandidateSelectionContext(
            operation: .modify,
            candidates: [PreviewFixtures.workEvent, alternateCandidate],
            patch: EventPatch(title: "Updated Alex time", startDate: nil, endDate: nil, location: nil, notes: nil),
            sourceText: "Move Alex meeting",
            parseRoute: .foundationModelsFailedOver
        )
        let candidateSelectionLight = render(CandidateSelectionView(context: candidateContext) { _ in }, colorScheme: .light, size: CGSize(width: 390, height: 640))
        let settingsDark = render(SettingsView(startSection: nil).environmentObject(app), colorScheme: .dark, size: CGSize(width: 390, height: 720))
        let settingsDiagnosticsLight = render(SettingsView(startSection: .diagnostics).environmentObject(app), colorScheme: .light, size: CGSize(width: 390, height: 720))
        let unavailableLight = render(
            UnavailableView(context: UnavailableContext(title: "Speech Unavailable", message: "Text entry and manual create remain available.", primaryAction: .openTextEntry, secondaryAction: .openManualCreate)) { _ in },
            colorScheme: .light,
            size: CGSize(width: 390, height: 520)
        )
        let agendaDeniedLight = render(
            DailyAgendaPager(selectedDay: PreviewFixtures.now, events: [], state: .denied(ErrorPresentation(title: "Calendar Access Needed", message: "Allow full calendar access to show and update your agenda.", recovery: "Open iOS Settings to grant Calendar access, then try again.")), onSelectDay: { _ in }),
            colorScheme: .light,
            size: CGSize(width: 390, height: 520)
        )

        assertSnapshot(homeLight, size: CGSize(width: 390, height: 844))
        assertSnapshot(homeDark, size: CGSize(width: 390, height: 844))
        assertSnapshot(textEntryDark, size: CGSize(width: 390, height: 520))
        assertSnapshot(onboardingLight, size: CGSize(width: 390, height: 720))
        assertSnapshot(correctionLight, size: CGSize(width: 390, height: 640))
        assertSnapshot(confirmationLight, size: CGSize(width: 390, height: 620))
        assertSnapshot(routedConfirmationLight, size: CGSize(width: 390, height: 660))
        assertSnapshot(candidateSelectionLight, size: CGSize(width: 390, height: 640))
        assertSnapshot(settingsDark, size: CGSize(width: 390, height: 720))
        assertSnapshot(settingsDiagnosticsLight, size: CGSize(width: 390, height: 720))
        assertSnapshot(unavailableLight, size: CGSize(width: 390, height: 520))
        assertSnapshot(agendaDeniedLight, size: CGSize(width: 390, height: 520))
        XCTAssertGreaterThan(abs(averageLuminance(homeLight) - averageLuminance(homeDark)), 0.02)
    }

    func testCommandOrbSnapshotsCaptureIdleAndRecordingStates() throws {
        let idle = render(CommandOrb(state: .idle, reduceMotion: true, showsIdleHint: true, onRecordingStart: {}, onRecordingFinish: {}, onDoubleTap: {}, onCancel: {}), colorScheme: .light, size: CGSize(width: 240, height: 180))
        let recording = render(CommandOrb(state: .recording(startedAt: Date()), reduceMotion: true, showsIdleHint: true, onRecordingStart: {}, onRecordingFinish: {}, onDoubleTap: {}, onCancel: {}), colorScheme: .light, size: CGSize(width: 240, height: 180))

        XCTAssertGreaterThan(try XCTUnwrap(idle.pngData()).count, 4_000)
        XCTAssertGreaterThan(try XCTUnwrap(recording.pngData()).count, 4_000)
        XCTAssertGreaterThan(colorDistance(centerColor(recording), centerColor(idle)), 0.15)
    }

    func testProcessingCardCommunicatesModelAndCalendarWork() throws {
        let parsing = render(ProcessingCard(state: .parsing("Schedule coffee tomorrow"), onCancel: {}), colorScheme: .light, size: CGSize(width: 390, height: 140))
        let applying = render(ProcessingCard(state: .applying, onCancel: {}), colorScheme: .dark, size: CGSize(width: 390, height: 140))

        XCTAssertGreaterThan(try XCTUnwrap(parsing.pngData()).count, 4_000)
        XCTAssertGreaterThan(try XCTUnwrap(applying.pngData()).count, 4_000)
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

    func testInitialPermissionInitializationWaitsForOnboardingAndRequestsCalendarOnce() async throws {
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

        app.presentOnboardingIfNeeded()
        await app.initializeRequiredPermissionsIfNeeded()

        XCTAssertEqual(app.activeSheet, .onboarding)
        XCTAssertEqual(speech.requestAuthorizationCount, 0)
        XCTAssertEqual(repo.requestFullAccessCount, 0)

        app.completeOnboarding()
        try await Task.sleep(nanoseconds: 80_000_000)
        await app.initializeRequiredPermissionsIfNeeded()

        XCTAssertEqual(speech.requestAuthorizationCount, 0)
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

@MainActor
final class V2UsabilityRegressionTests: XCTestCase {
    func testTodayActionUsesInjectedClockAndReloadsAgenda() async throws {
        let today = PreviewFixtures.now
        let repo = MockCalendarRepository(now: today)
        let deps = DependencyContainer(
            calendarRepository: repo,
            commandPipeline: CalendarCommandPipeline(parser: NaturalLanguageCalendarParser(now: { today }), policy: CalendarMutationPolicy(now: { today }), repository: repo),
            speechService: MockSpeechService(),
            modelProvider: MockModelProvider(),
            preferenceSummaryStore: InMemoryPreferenceSummaryStore(),
            capabilityService: DefaultCapabilityService(calendarRepository: repo, speechService: MockSpeechService(), modelProvider: MockModelProvider())
        )
        let tomorrow = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: 1, to: today))
        let model = CommandHomeModel(dependencies: deps, selectedDay: tomorrow, now: { today })

        model.selectToday()
        try await Task.sleep(nanoseconds: 120_000_000)

        XCTAssertTrue(Calendar.current.isDate(model.selectedDay, inSameDayAs: today))
        XCTAssertEqual(model.agendaState, .loaded)
        XCTAssertFalse(model.events.isEmpty)
    }

    func testDefaultCalendarSelectionPersistsAndReloadKeepsCheckmark() async throws {
        let repo = MockCalendarRepository()
        let prefs = InMemoryPreferenceSummaryStore()
        let deps = DependencyContainer(
            calendarRepository: repo,
            commandPipeline: CalendarCommandPipeline(parser: NaturalLanguageCalendarParser(now: { PreviewFixtures.now }), policy: CalendarMutationPolicy(now: { PreviewFixtures.now }, preferredCalendarID: { prefs.loadDefaultCalendarID() }), repository: repo),
            speechService: MockSpeechService(),
            modelProvider: MockModelProvider(),
            preferenceSummaryStore: prefs,
            capabilityService: DefaultCapabilityService(calendarRepository: repo, speechService: MockSpeechService(), modelProvider: MockModelProvider())
        )
        let model = CommandHomeModel(dependencies: deps, selectedDay: PreviewFixtures.now)
        await model.loadAgenda()
        let personal = try XCTUnwrap(model.calendars.first { $0.id == "personal" })

        model.selectCalendar(personal)
        XCTAssertEqual(model.selectedCalendar?.id, "personal")
        XCTAssertEqual(prefs.loadDefaultCalendarID(), "personal")

        await model.loadAgenda()
        XCTAssertEqual(model.selectedCalendar?.id, "personal")
    }

    func testInvalidSavedDefaultFallsBackAndCommunicatesRecovery() async throws {
        let repo = MockCalendarRepository()
        repo.calendars = [
            CalendarInfo(id: "old", title: "Old", accountName: "iCloud", allowsContentModifications: false, colorHex: nil),
            CalendarInfo(id: "work", title: "Work Calendar", accountName: "iCloud", allowsContentModifications: true, colorHex: "#0A84FF")
        ]
        let prefs = InMemoryPreferenceSummaryStore()
        prefs.saveDefaultCalendarID("old")
        let deps = DependencyContainer(
            calendarRepository: repo,
            commandPipeline: CalendarCommandPipeline(parser: NaturalLanguageCalendarParser(now: { PreviewFixtures.now }), policy: CalendarMutationPolicy(now: { PreviewFixtures.now }, preferredCalendarID: { prefs.loadDefaultCalendarID() }), repository: repo),
            speechService: MockSpeechService(),
            modelProvider: MockModelProvider(),
            preferenceSummaryStore: prefs,
            capabilityService: DefaultCapabilityService(calendarRepository: repo, speechService: MockSpeechService(), modelProvider: MockModelProvider())
        )
        let model = CommandHomeModel(dependencies: deps, selectedDay: PreviewFixtures.now)

        await model.loadAgenda()

        XCTAssertEqual(model.selectedCalendar?.id, "work")
        XCTAssertEqual(prefs.loadDefaultCalendarID(), "work")
        XCTAssertEqual(model.calendarSelectionNotice?.title, "Default calendar needs attention")
    }

    func testEventTapPresentsDetailAndUpdateUsesModifyConfirmation() throws {
        let model = CommandHomeModel(dependencies: .mock(), selectedDay: PreviewFixtures.now)
        let event = PreviewFixtures.workEvent
        var presented: AppSheet?
        model.sheetPresenter = { presented = $0 }

        model.openEventDetail(event)
        guard case .eventDetail(let detail)? = presented else { return XCTFail("Expected event detail sheet") }
        XCTAssertEqual(detail.event.id, event.id)

        let patch = EventPatch(title: "Updated Alex 1:1", startDate: nil, endDate: nil, location: nil, notes: nil)
        model.confirmUpdate(for: event, patch: patch)
        guard case .confirmation(let confirmation)? = presented else { return XCTFail("Expected modify confirmation") }
        XCTAssertEqual(confirmation.operation, .modify)
        XCTAssertEqual(confirmation.targetEventID, event.id)
        XCTAssertEqual(confirmation.patch, patch)
        XCTAssertNil(confirmation.afterDraft)
    }

    func testCalendarResultsCarryAppleCalendarDeepLink() async throws {
        let repo = MockCalendarRepository()
        let pipeline = CalendarCommandPipeline(
            parser: NaturalLanguageCalendarParser(now: { PreviewFixtures.now }),
            policy: CalendarMutationPolicy(now: { PreviewFixtures.now }),
            repository: repo
        )

        let output = await pipeline.process(text: "Standup tomorrow at 9am")

        guard case .result(let result) = output else { return XCTFail("Expected successful create result") }
        let url = try XCTUnwrap(result.actionURL)
        XCTAssertEqual(result.actionTitle, "Open in Calendar")
        XCTAssertEqual(url.scheme, "calshow")
        XCTAssertTrue(url.absoluteString.contains(String(result.event!.startDate.timeIntervalSinceReferenceDate)))
        XCTAssertEqual(result.parseRoute, .deterministicFallback)
    }

    func testCalendarAccessUnavailableRoutesToSystemSettingsAndDiagnostics() async throws {
        let repo = MockCalendarRepository()
        repo.authorization = .denied
        let pipeline = CalendarCommandPipeline(
            parser: NaturalLanguageCalendarParser(now: { PreviewFixtures.now }),
            policy: CalendarMutationPolicy(now: { PreviewFixtures.now }),
            repository: repo
        )

        let modifyOutput = await pipeline.process(text: "delete Alex today")
        guard case .unavailable(let modifyContext) = modifyOutput else { return XCTFail("Expected unavailable context") }
        XCTAssertEqual(modifyContext.primaryAction, .openSystemSettings)
        XCTAssertEqual(modifyContext.secondaryAction, .openSettings)

        let draft = EventDraft(title: "Manual draft", startDate: PreviewFixtures.now, endDate: PreviewFixtures.now.addingTimeInterval(3600), calendarID: "work", calendarName: "Work Calendar", location: nil, notes: nil)
        let createOutput = await pipeline.apply(draft: draft)
        guard case .unavailable(let createContext) = createOutput else { return XCTFail("Expected create unavailable context") }
        XCTAssertEqual(createContext.primaryAction, .openSystemSettings)
        XCTAssertEqual(createContext.secondaryAction, .openSettings)
    }

    func testPolicySearchAccessDeniedRoutesToSystemSettings() async throws {
        let repo = MockCalendarRepository()
        repo.authorization = .denied
        let parsed = ParsedCalendarCommand(
            originalText: "delete Alex today",
            localeIdentifier: "en-US",
            intent: .delete(query: EventQuery(phrase: "Alex today", day: PreviewFixtures.now, titleHint: "Alex")),
            confidence: 0.95,
            missingFields: [],
            warnings: []
        )

        let decision = await CalendarMutationPolicy(now: { PreviewFixtures.now }).decide(parsed: parsed, calendars: [], repository: repo)

        guard case .unavailable(let context) = decision else { return XCTFail("Expected unavailable context") }
        XCTAssertEqual(context.primaryAction, .openSystemSettings)
        XCTAssertEqual(context.secondaryAction, .openSettings)
    }

    func testConfirmationAccessDeniedRoutesToSystemSettings() async throws {
        let repo = MockCalendarRepository()
        repo.authorization = .denied
        let pipeline = CalendarCommandPipeline(
            parser: NaturalLanguageCalendarParser(now: { PreviewFixtures.now }),
            policy: CalendarMutationPolicy(now: { PreviewFixtures.now }),
            repository: repo
        )
        let context = ConfirmationContext(
            operation: .modify,
            title: "Update Event?",
            message: "Review before changing this existing calendar event.",
            before: PreviewFixtures.workEvent,
            afterDraft: nil,
            patch: EventPatch(title: "Updated Alex 1:1", startDate: nil, endDate: nil, location: nil, notes: nil),
            targetEventID: PreviewFixtures.workEvent.id,
            recurrenceScope: nil
        )

        let output = await pipeline.confirm(context, decision: .confirm(recurrenceScope: nil))

        guard case .unavailable(let unavailable) = output else { return XCTFail("Expected unavailable context") }
        XCTAssertEqual(unavailable.primaryAction, .openSystemSettings)
        XCTAssertEqual(unavailable.secondaryAction, .openSettings)
    }

    func testSystemSettingsActionUsesIOSSettingsURL() {
        XCTAssertEqual(UnavailableAction.openSystemSettings.title, "Open iOS Settings")
        XCTAssertEqual(UnavailableAction.openSystemSettings.systemImage, "gearshape")
        XCTAssertFalse(AppSettingsLink.url.absoluteString.isEmpty)
    }

    @MainActor
    func testDeniedSpeechPermissionOffersTextEntryAndSystemSettings() async throws {
        let speech = MockSpeechService(authorization: .denied)
        let deps = DependencyContainer(
            calendarRepository: MockCalendarRepository(),
            commandPipeline: CountingCommandPipeline(output: .failure(ErrorPresentation(title: "Unexpected", message: "Should not parse", recovery: nil))),
            speechService: speech,
            modelProvider: MockModelProvider(),
            preferenceSummaryStore: InMemoryPreferenceSummaryStore(),
            capabilityService: DefaultCapabilityService(calendarRepository: MockCalendarRepository(), speechService: speech, modelProvider: MockModelProvider())
        )
        let model = CommandHomeModel(dependencies: deps, selectedDay: PreviewFixtures.now)
        var presented: AppSheet?
        model.sheetPresenter = { presented = $0 }

        model.beginRecording()
        try await Task.sleep(nanoseconds: 60_000_000)

        guard case .speechUnavailable(let context)? = presented else { return XCTFail("Expected speech unavailable sheet") }
        XCTAssertEqual(context.primaryAction, .openTextEntry)
        XCTAssertEqual(context.secondaryAction, .openSystemSettings)
    }

    func testConfirmationResultPreservesParserRoute() async throws {
        let repo = MockCalendarRepository()
        let pipeline = CalendarCommandPipeline(
            parser: NaturalLanguageCalendarParser(now: { PreviewFixtures.now }),
            policy: CalendarMutationPolicy(now: { PreviewFixtures.now }),
            repository: repo
        )

        let output = await pipeline.process(text: "delete Alex today")
        guard case .confirmation(let context) = output else { return XCTFail("Expected confirmation") }
        XCTAssertEqual(context.parseRoute, .deterministicFallback)

        let result = await pipeline.confirm(context, decision: .confirm(recurrenceScope: .thisEvent))
        guard case .result(let state) = result else { return XCTFail("Expected delete result") }
        XCTAssertEqual(state.parseRoute, .deterministicFallback)
    }

    func testCorrectedDraftResultPreservesParserRoute() async throws {
        let repo = MockCalendarRepository()
        let event = CalendarEvent(
            id: "corrected-event",
            title: "Corrected event",
            calendarID: "work",
            calendarName: "Work Calendar",
            accountName: "iCloud",
            startDate: PreviewFixtures.now,
            endDate: PreviewFixtures.now.addingTimeInterval(3600),
            isAllDay: false,
            location: nil,
            notes: nil,
            isRecurring: false,
            calendarColorHex: "#0A84FF"
        )
        let pipeline = CountingCommandPipeline(output: .result(CommandResultViewState(title: "Added to Calendar", message: "Corrected event", event: event, actionTitle: "Open in Calendar")))
        let deps = DependencyContainer(
            calendarRepository: repo,
            commandPipeline: pipeline,
            speechService: MockSpeechService(),
            modelProvider: MockModelProvider(),
            preferenceSummaryStore: InMemoryPreferenceSummaryStore(),
            capabilityService: DefaultCapabilityService(calendarRepository: repo, speechService: MockSpeechService(), modelProvider: MockModelProvider())
        )
        let model = CommandHomeModel(dependencies: deps, selectedDay: PreviewFixtures.now)
        let draft = EventDraft(title: "Corrected event", startDate: PreviewFixtures.now, endDate: PreviewFixtures.now.addingTimeInterval(3600), calendarID: "work", calendarName: "Work Calendar", location: nil, notes: nil)

        await model.applyCorrectedDraft(draft, parseRoute: .foundationModelsFailedOver)

        XCTAssertEqual(model.latestResult?.parseRoute, .foundationModelsFailedOver)
    }

    func testCancellingConfirmationDoesNotEnterPipelineOrShowError() async {
        let repo = MockCalendarRepository()
        let event = CalendarEvent(
            id: "cancel-confirmation-event",
            title: "Cancelled confirmation",
            calendarID: "work",
            calendarName: "Work Calendar",
            accountName: "iCloud",
            startDate: PreviewFixtures.now,
            endDate: PreviewFixtures.now.addingTimeInterval(3600),
            isAllDay: false,
            location: nil,
            notes: nil,
            isRecurring: false,
            calendarColorHex: "#0A84FF"
        )
        let pipeline = CountingCommandPipeline(output: .result(CommandResultViewState(title: "Unexpected", message: "Should not apply", event: event, actionTitle: nil)))
        let deps = DependencyContainer(
            calendarRepository: repo,
            commandPipeline: pipeline,
            speechService: MockSpeechService(),
            modelProvider: MockModelProvider(),
            preferenceSummaryStore: InMemoryPreferenceSummaryStore(),
            capabilityService: DefaultCapabilityService(calendarRepository: repo, speechService: MockSpeechService(), modelProvider: MockModelProvider())
        )
        let model = CommandHomeModel(dependencies: deps, selectedDay: PreviewFixtures.now)

        await model.resolveConfirmation(PreviewFixtures.deleteConfirmationContext, decision: .cancel)

        XCTAssertTrue(pipeline.confirmedDecisions.isEmpty)
        XCTAssertEqual(model.commandState, .idle)
        XCTAssertNil(model.latestError)
        XCTAssertNil(model.latestResult)
    }

    func testCandidateSelectionPreservesParserRouteIntoConfirmation() {
        let model = CommandHomeModel(dependencies: .mock(), selectedDay: PreviewFixtures.now)
        let context = CandidateSelectionContext(
            operation: .modify,
            candidates: [PreviewFixtures.workEvent],
            patch: EventPatch(title: "Updated Review", startDate: nil, endDate: nil, location: nil, notes: nil),
            sourceText: "Move review",
            parseRoute: .foundationModelsGenerated
        )
        var presented: AppSheet?
        model.sheetPresenter = { presented = $0 }

        model.selectCandidate(PreviewFixtures.workEvent, for: context)

        guard case .confirmation(let confirmation)? = presented else { return XCTFail("Expected confirmation") }
        XCTAssertEqual(confirmation.parseRoute, .foundationModelsGenerated)
    }

    func testReadinessChecklistSeparatesAutomatedAndManualReleaseGates() {
        let calendar = CalendarInfo(id: "work", title: "Work Calendar", accountName: "iCloud", allowsContentModifications: true, colorHex: "#0A84FF")
        let readyItems = AppStoreReadinessChecklist.items(
            summary: CapabilitySummary(calendar: .allowed, speech: .allowed, model: .allowed, preferredLocales: ["en-US"], runsOnDevice: true),
            writableCalendarCount: 1,
            selectedCalendar: calendar
        )

        XCTAssertEqual(readyItems.first { $0.id == "calendar-access" }?.state, .ready)
        XCTAssertEqual(readyItems.first { $0.id == "writable-calendar" }?.state, .ready)
        XCTAssertEqual(readyItems.first { $0.id == "speech" }?.state, .ready)
        XCTAssertEqual(readyItems.first { $0.id == "foundation-models" }?.state, .ready)
        XCTAssertEqual(readyItems.first { $0.id == "deterministic-parser" }?.state, .ready)
        XCTAssertEqual(readyItems.first { $0.id == "privacy-manifest" }?.state, .ready)
        XCTAssertEqual(readyItems.first { $0.id == "calendar-open" }?.state, .manualGate)
        XCTAssertEqual(readyItems.first { $0.id == "store-assets" }?.state, .manualGate)

        let blockedItems = AppStoreReadinessChecklist.items(
            summary: CapabilitySummary(calendar: .denied, speech: .notDetermined, model: .unavailable, preferredLocales: ["en-US"], runsOnDevice: false),
            writableCalendarCount: 0,
            selectedCalendar: nil
        )

        XCTAssertEqual(blockedItems.first { $0.id == "calendar-access" }?.state, .needsAttention)
        XCTAssertEqual(blockedItems.first { $0.id == "writable-calendar" }?.state, .needsAttention)
        XCTAssertEqual(blockedItems.first { $0.id == "speech" }?.state, .manualGate)
        XCTAssertEqual(blockedItems.first { $0.id == "foundation-models" }?.state, .needsAttention)
        XCTAssertEqual(blockedItems.first { $0.id == "deterministic-parser" }?.state, .ready)
        XCTAssertEqual(blockedItems.first { $0.id == "privacy-manifest" }?.state, .ready)
    }

    func testFoundationModelsNotReadyIsManualGateWhileFallbackStaysReady() {
        let items = AppStoreReadinessChecklist.items(
            summary: CapabilitySummary(calendar: .allowed, speech: .allowed, model: .notDetermined, preferredLocales: ["en-US"], runsOnDevice: false),
            writableCalendarCount: 1,
            selectedCalendar: CalendarInfo(id: "work", title: "Work Calendar", accountName: "iCloud", allowsContentModifications: true, colorHex: nil)
        )

        XCTAssertEqual(items.first { $0.id == "foundation-models" }?.state, .manualGate)
        XCTAssertEqual(items.first { $0.id == "deterministic-parser" }?.state, .ready)
    }

    func testDraftTimeRangePreservesDurationWhenStartMoves() {
        let start = PreviewFixtures.now
        let end = start.addingTimeInterval(5400)
        let movedStart = start.addingTimeInterval(7200)

        let adjustedEnd = DraftTimeRangePolicy.endDateAfterMovingStart(oldStart: start, oldEnd: end, newStart: movedStart)

        XCTAssertEqual(adjustedEnd.timeIntervalSince(movedStart), 5400, accuracy: 0.1)
        XCTAssertGreaterThan(adjustedEnd, movedStart)
    }

    func testDraftTimeRangeRepairsInvalidEndDate() {
        let start = PreviewFixtures.now
        let invalidEnd = start.addingTimeInterval(-300)

        let adjustedEnd = DraftTimeRangePolicy.validEndDate(start: start, proposedEnd: invalidEnd)

        XCTAssertEqual(adjustedEnd.timeIntervalSince(start), DraftTimeRangePolicy.minimumDuration, accuracy: 0.1)
        XCTAssertGreaterThan(adjustedEnd, start)
    }

    func testSettingsSectionDeepLinksMatchRecoveryTargets() {
        XCTAssertEqual(SettingsSection.diagnostics.title, "v0.3 Readiness")
        XCTAssertEqual(SettingsSection.diagnostics.accessibilityIdentifier, "settingsSection-diagnostics")
        XCTAssertEqual(SettingsSection.automation.title, "Safety Mode")
        XCTAssertEqual(SettingsSection.language.title, "Default Calendar")
        XCTAssertEqual(SettingsSection.privacy.title, "Local Preferences")
    }

    func testOpeningTextEntryHidesPersistentHint() {
        let app = AppModel(dependencies: .mock())
        XCTAssertTrue(app.commandHomeModel.showsCommandHint)
        app.openTextEntry()
        XCTAssertFalse(app.commandHomeModel.showsCommandHint)
    }

    @MainActor
    func testAgendaFailureActionsRouteByFailureType() {
        var systemSettingsCount = 0
        var diagnosticsCount = 0
        var retryCount = 0

        let denied = DailyAgendaPager(
            selectedDay: PreviewFixtures.now,
            events: [],
            state: .denied(ErrorPresentation(title: "Denied", message: "Calendar access denied", recovery: nil)),
            onRetryAgenda: { retryCount += 1 },
            onOpenSystemSettings: { systemSettingsCount += 1 },
            onOpenDiagnostics: { diagnosticsCount += 1 },
            onSelectDay: { _ in }
        )
        denied.performAgendaFailurePrimaryAction()
        denied.performAgendaFailureSecondaryAction()

        XCTAssertEqual(systemSettingsCount, 1)
        XCTAssertEqual(retryCount, 1)
        XCTAssertEqual(diagnosticsCount, 0)

        let failed = DailyAgendaPager(
            selectedDay: PreviewFixtures.now,
            events: [],
            state: .failed(ErrorPresentation(title: "Load Failed", message: "Unexpected error", recovery: nil)),
            onRetryAgenda: { retryCount += 1 },
            onOpenSystemSettings: { systemSettingsCount += 1 },
            onOpenDiagnostics: { diagnosticsCount += 1 },
            onSelectDay: { _ in }
        )
        failed.performAgendaFailurePrimaryAction()
        failed.performAgendaFailureSecondaryAction()

        XCTAssertEqual(systemSettingsCount, 1)
        XCTAssertEqual(retryCount, 2)
        XCTAssertEqual(diagnosticsCount, 1)
    }

    func testBlankTextCommandDoesNotEnterPipeline() async {
        let pipeline = CountingCommandPipeline(output: .failure(ErrorPresentation(title: "Unexpected", message: "Should not run", recovery: nil)))
        let repo = MockCalendarRepository()
        let speech = MockSpeechService()
        let deps = DependencyContainer(
            calendarRepository: repo,
            commandPipeline: pipeline,
            speechService: speech,
            modelProvider: MockModelProvider(),
            preferenceSummaryStore: InMemoryPreferenceSummaryStore(),
            capabilityService: DefaultCapabilityService(calendarRepository: repo, speechService: speech, modelProvider: MockModelProvider())
        )
        let model = CommandHomeModel(dependencies: deps, selectedDay: PreviewFixtures.now)

        await model.submit(text: "   \n\t  ")

        XCTAssertTrue(pipeline.processInputs.isEmpty)
        XCTAssertEqual(model.latestError?.title, "Command Needed")
        guard case .failed(let error) = model.commandState else { return XCTFail("Expected empty command failure") }
        XCTAssertEqual(error.title, "Command Needed")
    }

    func testTextCommandTrimsBeforePipelineProcessing() async {
        let pipeline = CountingCommandPipeline(output: .failure(ErrorPresentation(title: "Stopped after trim check", message: "No mutation needed", recovery: nil)))
        let repo = MockCalendarRepository()
        let speech = MockSpeechService()
        let deps = DependencyContainer(
            calendarRepository: repo,
            commandPipeline: pipeline,
            speechService: speech,
            modelProvider: MockModelProvider(),
            preferenceSummaryStore: InMemoryPreferenceSummaryStore(),
            capabilityService: DefaultCapabilityService(calendarRepository: repo, speechService: speech, modelProvider: MockModelProvider())
        )
        let model = CommandHomeModel(dependencies: deps, selectedDay: PreviewFixtures.now)

        await model.submit(text: "  Coffee tomorrow at noon  ")

        XCTAssertEqual(pipeline.processInputs, ["Coffee tomorrow at noon"])
    }

    func testManualCreateFromEmptyAgendaUsesFocusedReason() throws {
        let model = CommandHomeModel(dependencies: .mock(), selectedDay: PreviewFixtures.now)
        var presented: AppSheet?
        model.sheetPresenter = { presented = $0 }

        model.openManualCreate(reason: "Create an event from an empty agenda.")

        guard case .manualEventForm(let context)? = presented else { return XCTFail("Expected manual event form") }
        XCTAssertEqual(context.reason, "Create an event from an empty agenda.")
        XCTAssertEqual(context.draft.calendarID, nil)
    }

    func testStaleAgendaLoadCannotOverwriteNewerSelectedDay() async throws {
        let today = PreviewFixtures.now
        let tomorrow = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: 1, to: today))
        let repo = MockCalendarRepository(now: today)
        repo.fetchEventsDelayNanoseconds = { day in
            Calendar.current.isDate(day, inSameDayAs: today) ? 160_000_000 : 0
        }
        let deps = DependencyContainer(
            calendarRepository: repo,
            commandPipeline: CalendarCommandPipeline(parser: NaturalLanguageCalendarParser(now: { today }), policy: CalendarMutationPolicy(now: { today }), repository: repo),
            speechService: MockSpeechService(),
            modelProvider: MockModelProvider(),
            preferenceSummaryStore: InMemoryPreferenceSummaryStore(),
            capabilityService: DefaultCapabilityService(calendarRepository: repo, speechService: MockSpeechService(), modelProvider: MockModelProvider())
        )
        let model = CommandHomeModel(dependencies: deps, selectedDay: today, now: { today })

        let staleLoad = Task { await model.loadAgenda() }
        try await Task.sleep(nanoseconds: 30_000_000)
        model.selectedDay = tomorrow
        await model.loadAgenda()
        await staleLoad.value

        XCTAssertTrue(Calendar.current.isDate(model.selectedDay, inSameDayAs: tomorrow))
        XCTAssertEqual(model.agendaState, .loaded)
        XCTAssertTrue(model.events.isEmpty)
    }

    func testCancelProcessingSuppressesLateCommandResult() async throws {
        let repo = MockCalendarRepository()
        let event = CalendarEvent(
            id: "late-ai-result",
            title: "Late command",
            calendarID: "work",
            calendarName: "Work Calendar",
            accountName: "iCloud",
            startDate: PreviewFixtures.now,
            endDate: PreviewFixtures.now.addingTimeInterval(3600),
            isAllDay: false,
            location: nil,
            notes: nil,
            isRecurring: false,
            calendarColorHex: "#0A84FF"
        )
        let pipeline = DelayedCommandPipeline(
            output: .result(CommandResultViewState(title: "Added to Calendar", message: "Late command", event: event, actionTitle: "Open in Calendar")),
            delayNanoseconds: 160_000_000
        )
        let deps = DependencyContainer(
            calendarRepository: repo,
            commandPipeline: pipeline,
            speechService: MockSpeechService(),
            modelProvider: MockModelProvider(),
            preferenceSummaryStore: InMemoryPreferenceSummaryStore(),
            capabilityService: DefaultCapabilityService(calendarRepository: repo, speechService: MockSpeechService(), modelProvider: MockModelProvider())
        )
        let model = CommandHomeModel(dependencies: deps, selectedDay: PreviewFixtures.now)

        let command = Task { await model.submit(text: "Schedule late command") }
        try await Task.sleep(nanoseconds: 30_000_000)
        model.cancelProcessing()
        await command.value

        XCTAssertEqual(model.commandState, .idle)
        XCTAssertNil(model.latestResult)
        XCTAssertNil(model.latestError)
    }
}

private final class DelayedCommandPipeline: CalendarCommandPipelineProtocol {
    let output: CalendarCommandPipelineOutput
    let delayNanoseconds: UInt64

    init(output: CalendarCommandPipelineOutput, delayNanoseconds: UInt64) {
        self.output = output
        self.delayNanoseconds = delayNanoseconds
    }

    func process(text: String) async -> CalendarCommandPipelineOutput {
        await delay()
        return output
    }

    func apply(draft: EventDraft) async -> CalendarCommandPipelineOutput {
        await delay()
        return output
    }

    func confirm(_ context: ConfirmationContext, decision: ConfirmationDecision) async -> CalendarCommandPipelineOutput {
        await delay()
        return output
    }

    private func delay() async {
        try? await Task.sleep(nanoseconds: delayNanoseconds)
    }
}

private final class CountingCommandPipeline: CalendarCommandPipelineProtocol {
    private let output: CalendarCommandPipelineOutput
    var processInputs: [String] = []
    var confirmedDecisions: [ConfirmationDecision] = []

    init(output: CalendarCommandPipelineOutput) {
        self.output = output
    }

    func process(text: String) async -> CalendarCommandPipelineOutput {
        processInputs.append(text)
        return output
    }

    func apply(draft: EventDraft) async -> CalendarCommandPipelineOutput {
        output
    }

    func confirm(_ context: ConfirmationContext, decision: ConfirmationDecision) async -> CalendarCommandPipelineOutput {
        confirmedDecisions.append(decision)
        return output
    }
}
