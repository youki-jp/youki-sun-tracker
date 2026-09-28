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

    func testGoldenHourAlarmOnOlderIOS() throws {
        if #available(iOS 26, *) { throw XCTSkip("Requires an older iOS runtime") }
        app.launchArguments = ["-uiSkyFixture"]
        app.launchEnvironment["BACKEND_URL"] = "http://127.0.0.1:1"
        app.launch()
        let button = app.buttons["wakeAlarmButton"]
        XCTAssertTrue(button.waitForExistence(timeout: 10))
        XCTAssertEqual(button.label, "Set alarm")
        button.tap()
        XCTAssertTrue(app.staticTexts["alarmUnavailable"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.segmentedControls["alarmEventPicker"].exists)
        XCTAssertTrue(app.steppers["alarmLeadStepper"].exists)
        XCTAssertFalse(app.buttons["scheduleAlarmButton"].exists)
        XCTAssertFalse(app.staticTexts["confirmedAlarm"].exists)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Golden-hour alarm availability"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testSyntheticSkySceneAndAttribution() throws {
        app.launchArguments = ["-uiSkyFixture"]
        app.launchEnvironment["BACKEND_URL"] = "http://127.0.0.1:1"
        app.launch()
        XCTAssertTrue(app.otherElements["skyAppearance"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["forecastStatus"].exists)
        XCTAssertFalse(app.staticTexts["Live sky and forecast"].exists)
        XCTAssertTrue(app.otherElements["skyAppearance"].label.contains("visible sun"))
        let locationButton = app.buttons["locationButton"]
        XCTAssertTrue(locationButton.label.contains("Tokyo"), locationButton.label)
        XCTAssertFalse(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Illustrated forecast")).firstMatch.exists)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Synthetic sunlight and clouds"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        locationButton.tap()
        let attribution = app.descendants(matching: .any)["weatherAttribution"]
        XCTAssertTrue(attribution.waitForExistence(timeout: 3))
        XCTAssertTrue(attribution.label.contains("Open-Meteo"))
        app.swipeDown()
        app.otherElements["skyAppearance"].coordinate(withNormalizedOffset: CGVector(dx: 0.08, dy: 0.92)).tap()
        XCTAssertTrue(app.staticTexts["Color analysis"].waitForExistence(timeout: 3))
        let expanded = XCTAttachment(screenshot: app.screenshot())
        expanded.name = "Expanded synthetic sunlight and clouds"
        expanded.lifetime = .keepAlways
        add(expanded)
    }

    func testOvercastAndMissingWeatherSceneFixtures() throws {
        for (argument, expected) in [
            ("-uiSkyFixtureOvercast", "no visible sun"),
            ("-uiSkyFixtureMissing", "limited weather data"),
            ("-uiSkyFixtureNight", "no visible sun")
        ] {
            app.terminate()
            app.launchArguments = [argument]
            app.launch()
            let sky = app.otherElements["skyAppearance"]
            XCTAssertTrue(sky.waitForExistence(timeout: 10), argument)
            XCTAssertTrue(sky.label.contains(expected), "\(argument): \(sky.label)")
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = "\(argument) scene"
            screenshot.lifetime = .keepAlways
            add(screenshot)
        }
    }

    func testMainControlsAndSheets() throws {
        app.launch()

        XCTAssertTrue(app.buttons["locationButton"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["expandButton"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["calendarButton"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["settingsButton"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["wakeAlarmButton"].waitForExistence(timeout: 5))

        XCTAssertFalse(app.staticTexts["forecastStatus"].exists)
        app.buttons["locationButton"].tap()
        XCTAssertFalse(app.buttons["manualLocationButton"].isEnabled)
        app.buttons["locationsDoneButton"].tap()

        app.buttons["calendarButton"].tap()
        XCTAssertTrue(app.staticTexts["Forecast calendar"].waitForExistence(timeout: 2))
        app.buttons["calendarInfoButton"].tap()
        app.buttons["calendarDoneButton"].tap()

        app.buttons["settingsButton"].tap()
        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 2))
        app.buttons["accountButton"].tap()
        XCTAssertTrue(app.staticTexts["Your sky, every day."].waitForExistence(timeout: 2))
        app.buttons["signInEntryLink"].tap()
        XCTAssertTrue(app.staticTexts["Welcome back."].exists)
        XCTAssertTrue(app.buttons["appleSignInButton"].label.contains("Sign in with Apple"))
        app.buttons["createAccountEntryLink"].tap()
        XCTAssertTrue(app.staticTexts["Your sky, every day."].exists)
        XCTAssertTrue(app.buttons["appleSignInButton"].label.contains("Sign up with Apple"))
        app.buttons["accountDoneButton"].tap()

        app.buttons["settingsButton"].tap()
        app.buttons["allSettingsButton"].tap()
        XCTAssertTrue(app.staticTexts["Locations"].waitForExistence(timeout: 2))
        app.buttons["useLocationButton"].tap()
        app.buttons["expandButton"].tap()
        XCTAssertTrue(app.staticTexts["Color analysis"].waitForExistence(timeout: 2))
    }

    func testManualCoordinatesStaySampleUntilSignIn() throws {
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
        XCTAssertTrue(app.buttons["Sign in for live sky"].waitForExistence(timeout: 5))
        app.buttons["Sign in for live sky"].tap()
        XCTAssertTrue(app.staticTexts["Your sky, every day."].waitForExistence(timeout: 5))
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
