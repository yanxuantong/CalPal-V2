import XCTest

final class CalPalSmokeUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testDemoLaunchCoversCoreSmokePaths() {
        let app = XCUIApplication()
        app.launchArguments = [AppLaunchArgument.demo]
        app.launch()

        XCTAssertTrue(element("agendaTimeline", in: app).waitForExistence(timeout: 10))

        openAndVerifySettings(in: app)
        openAndVerifyTextEntry(in: app)
        openAndVerifyManualCreateFromEmptyDay(in: app)
    }

    private func openAndVerifySettings(in app: XCUIApplication) {
        button("commandHomeSettings", in: app).tap()
        XCTAssertTrue(element("readinessSummary", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(scrollToElement("readinessItem-calendar-access", in: app).exists)
        XCTAssertTrue(scrollToElement("readinessItem-foundation-models", in: app).exists)
        XCTAssertTrue(scrollToElement("readinessItem-remote-ai-boundary", in: app).exists)
        XCTAssertTrue(scrollToElement("readinessItem-store-assets", in: app).exists)
        XCTAssertTrue(scrollToElement("privacyBoundarySummary", in: app).exists)
        XCTAssertTrue(scrollToElement("localDiagnosticsSummary", in: app).exists)
        XCTAssertTrue(scrollToElement("resetLocalDiagnostics", in: app).exists)
        button("settingsDone", in: app).tap()
        XCTAssertTrue(button("commandHomeSettings", in: app).waitForExistence(timeout: 5))
    }

    private func openAndVerifyTextEntry(in app: XCUIApplication) {
        button("commandOrb", in: app).doubleTap()
        let field = element("calendarCommandTextField", in: app)
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        XCTAssertTrue(element("textCommandReadinessHint", in: app).exists)
        field.tap()
        field.typeText("Coffee tomorrow at noon")
        XCTAssertTrue(button("textCommandSend", in: app).isEnabled)
        button("textEntryCancel", in: app).tap()
        XCTAssertTrue(button("commandHomeSettings", in: app).waitForExistence(timeout: 5))
    }

    private func openAndVerifyManualCreateFromEmptyDay(in app: XCUIApplication) {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        button("weekDay_\(Self.dateIdentifier.string(from: tomorrow))", in: app).tap()

        let manualCreate = button("emptyAgendaManualCreate", in: app)
        XCTAssertTrue(manualCreate.waitForExistence(timeout: 5))
        manualCreate.tap()

        XCTAssertTrue(element("targetCalendarRow", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(element("draftSaveReadinessHint", in: app).exists)
        XCTAssertTrue(button("manualEventSave", in: app).exists)
        button("manualEventCancel", in: app).tap()

        let today = button("commandHomeToday", in: app)
        XCTAssertTrue(today.waitForExistence(timeout: 5))
        today.tap()
        XCTAssertTrue(element("agendaTimeline", in: app).waitForExistence(timeout: 5))
    }

    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func button(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons[identifier]
    }

    private func scrollToElement(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        let target = element(identifier, in: app)
        if target.waitForExistence(timeout: 1) {
            return target
        }

        for _ in 0..<6 {
            app.swipeUp()
            if target.waitForExistence(timeout: 1) {
                return target
            }
        }

        return target
    }

    private static let dateIdentifier: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = .current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

private enum AppLaunchArgument {
    static let demo = "--calpal-demo"
}
