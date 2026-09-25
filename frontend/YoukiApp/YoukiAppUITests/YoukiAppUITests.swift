import XCTest

final class YoukiAppUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiAudit"]
        app.launchEnvironment["BACKEND_URL"] = "http://localhost:3000"

        addUIInterruptionMonitor(withDescription: "Location permission") { alert in
            if alert.buttons["Allow While Using App"].exists {
                alert.buttons["Allow While Using App"].tap()
                return true
            }

            if alert.buttons["Allow Once"].exists {
                alert.buttons["Allow Once"].tap()
                return true
            }

            return false
        }
    }

    func testMainControlsAndSheets() throws {
        app.launch()

        XCTAssertTrue(app.buttons["locationButton"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["expandButton"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["calendarButton"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["settingsButton"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["wakeAlarmButton"].waitForExistence(timeout: 5))

        XCTAssertEqual(app.staticTexts["forecastStatus"].label, "Sample sky and forecast")
        app.buttons["locationButton"].tap()
        XCTAssertFalse(app.buttons["manualLocationButton"].isEnabled)
        app.swipeDown()

        app.buttons["expandButton"].tap()
        XCTAssertTrue(app.staticTexts["Color analysis"].waitForExistence(timeout: 2))
        app.buttons["expandButton"].tap()
        XCTAssertTrue(app.buttons["settingsButton"].waitForExistence(timeout: 2))

        app.buttons["calendarButton"].tap()
        XCTAssertTrue(app.staticTexts["Forecast calendar"].waitForExistence(timeout: 2))
        app.buttons["calendarInfoButton"].tap()
        app.swipeDown()

        app.buttons["settingsButton"].tap()
        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 2))
        app.buttons["upgradeButton"].tap()
        XCTAssertTrue(app.staticTexts["Youki Pro"].waitForExistence(timeout: 2))
        app.buttons["monthlyPlanButton"].tap()
        app.buttons["startTrialButton"].tap()

        app.buttons["settingsButton"].tap()
        app.buttons["allSettingsButton"].tap()
        XCTAssertTrue(app.staticTexts["Locations"].waitForExistence(timeout: 2))
        app.buttons["useLocationButton"].tap()
    }

    func testManualCoordinatesAndLiveEventSelection() throws {
        app.launch()
        app.buttons["locationButton"].tap()
        let showSky = app.buttons["manualLocationButton"]
        XCTAssertFalse(showSky.isEnabled)
        let latitude = app.textFields["latitudeField"]
        latitude.tap()
        latitude.typeText("91\n")
        app.textFields["longitudeField"].tap()
        app.textFields["longitudeField"].typeText("139.6503\n")
        XCTAssertFalse(showSky.isEnabled)
        latitude.tap()
        latitude.typeText(XCUIKeyboardKey.delete.rawValue + XCUIKeyboardKey.delete.rawValue + "35.6762\n")
        XCTAssertTrue(showSky.isEnabled)
        showSky.tap()
        let status = app.staticTexts["forecastStatus"]
        let live = NSPredicate(
            format: "label == %@ OR label == %@",
            "Live sky and forecast", "Live sky · partial atmosphere"
        )
        XCTAssertTrue(waitFor(live, element: status, timeout: 90), "Requires both live APIs at http://localhost:3000 with Tokyo data.")

        var eventTimes: [String] = []
        for moment in ["sunrise", "daylight", "sunset"] {
            let button = app.buttons["moment." + moment]
            let enabled = NSPredicate(format: "isEnabled == true")
            XCTAssertTrue(waitFor(enabled, element: button, timeout: 15), "\(moment) should be available in the live timeline.")
            tapMoment(moment)
            app.scrollViews.firstMatch.swipeDown()
            let eventTime = app.staticTexts["selectedEventTime"]
            XCTAssertTrue(eventTime.waitForExistence(timeout: 5))
            XCTAssertTrue(button.label.contains(eventTime.label), "\(moment) should show its selected location-local milestone time.")
            eventTimes.append(eventTime.label)
        }
        XCTAssertEqual(Set(eventTimes).count, 3, "Sunrise, solar noon, and sunset should select distinct timeline times.")
        app.buttons["expandButton"].tap()
        XCTAssertTrue(app.staticTexts["Color analysis"].waitForExistence(timeout: 2))
        app.buttons["expandButton"].tap()
    }

    private func tapMoment(_ id: String) {
        let button = app.buttons["moment." + id]
        for _ in 0..<4 where !button.isHittable {
            app.scrollViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(button.isHittable)
        button.tap()
    }

    private func waitFor(_ predicate: NSPredicate, element: XCUIElement, timeout: TimeInterval) -> Bool {
        XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: element)], timeout: timeout) == .completed
    }
}
