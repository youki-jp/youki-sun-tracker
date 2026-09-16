import XCTest

final class YoukiAppUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiAudit"]

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

        app.buttons["moment.firstLight"].tap()
        app.buttons["moment.goldenHour"].tap()
        app.buttons["moment.sunset"].tap()

        app.buttons["wakeAlarmButton"].tap()
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
}
