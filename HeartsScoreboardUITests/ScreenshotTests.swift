import XCTest

/// Captures the five App Store scenes. Run via scripts/screenshots.sh (scheme HeartsScoreboardScreenshots).
/// Attachments are named "1 - Main" ... "5 - Dark". The app runs with `-screenshotDemo` (DEBUG only),
/// which loads fixed data into an isolated in-memory store.
final class ScreenshotTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(dark: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        var args = ["-screenshotDemo", "-screenshotAppearance", dark ? "dark" : "light"]
        // TEST_RUNNER_SCREENSHOT_LOCALE=de on the xcodebuild command line arrives here as SCREENSHOT_LOCALE.
        if let locale = ProcessInfo.processInfo.environment["SCREENSHOT_LOCALE"], !locale.isEmpty {
            args += ["-AppleLanguages", "(\(locale))", "-AppleLocale", locale]
        }
        app.launchArguments = args
        app.launch()
        XCTAssertTrue(app.buttons["settingsButton"].waitForExistence(timeout: 15), "Main screen did not appear")
        return app
    }


    private func capture(_ name: String) {
        // Let sheet/navigation animations settle before capturing.
        Thread.sleep(forTimeInterval: 1.0)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testMain() {
        _ = launch()
        capture("1 - Main")
    }

    func testRoundInput() {
        let app = launch()
        // Compact width: the round input is a sheet. Regular width: it is already inline.
        if app.buttons["nextRoundButton"].exists {
            app.buttons["nextRoundButton"].tap()
        }
        XCTAssertTrue(app.buttons["roundInput.quick.Ava"].waitForExistence(timeout: 10))
        app.buttons["roundInput.quick.Ava"].tap()
        app.buttons["roundInput.queen.Ben"].tap()
        app.buttons["roundInput.quick.Cleo"].tap()
        capture("2 - Round Input")
    }

    func testGameSummary() {
        let app = launch()
        app.buttons["historyButton"].tap()
        let row = app.descendants(matching: .any)["history.row"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        Thread.sleep(forTimeInterval: 1.5) // let the sheet finish presenting before tapping
        row.tap()
        XCTAssertTrue(app.descendants(matching: .any)["historyDetail.date"].firstMatch.waitForExistence(timeout: 10))
        capture("3 - Game Summary")
    }

    func testSettings() {
        let app = launch()
        app.buttons["settingsButton"].tap()
        XCTAssertTrue(app.buttons["settings.done"].waitForExistence(timeout: 10))
        capture("4 - Settings")
    }

    func testDark() {
        _ = launch(dark: true)
        capture("5 - Dark")
    }
}
