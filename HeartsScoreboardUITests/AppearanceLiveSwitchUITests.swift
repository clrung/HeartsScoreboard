import XCTest

/// Settings › Appearance must restyle the whole window live: the board behind the open sheet, the sheet,
/// and the board again after Done. (Regression: the board stayed light behind a dark Settings sheet.)
/// `BoardStyleProbe` (DEBUG) reports the board view's effective interface style.
/// Env: SHOT_DIR (optional) saves a screenshot after each step.
final class AppearanceLiveSwitchUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        XCUIDevice.shared.appearance = .light
        app = XCUIApplication()
        app.launchArguments = ["-screenshotDemo", "-screenshotFollowAppearance"]
        app.launch()
    }

    override func tearDown() {
        XCUIDevice.shared.appearance = .light
    }

    private var boardStyle: String? {
        app.descendants(matching: .any)["appearance.boardStyle"].value as? String
    }

    private func waitForBoardStyle(_ expected: String, _ message: String, file: StaticString = #filePath, line: UInt = #line) {
        let probe = app.descendants(matching: .any)["appearance.boardStyle"]
        let predicate = NSPredicate(format: "value == %@", expected)
        let result = XCTWaiter().wait(for: [expectation(for: predicate, evaluatedWith: probe)], timeout: 5)
        if result != .completed { snap("failed-expected-\(expected)") }
        XCTAssertEqual(result, .completed, "\(message) (board style is \(boardStyle ?? "missing"))", file: file, line: line)
    }

    private func snap(_ tag: String) {
        guard let dir = ProcessInfo.processInfo.environment["SHOT_DIR"] else { return }
        try? app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(dir)/\(tag).png"))
    }

    func testAppearancePickerRestylesBoardBehindSettingsLive() {
        XCTAssertTrue(app.buttons["settingsButton"].waitForExistence(timeout: 15))
        waitForBoardStyle("light", "board starts light")
        app.buttons["settingsButton"].tap()
        XCTAssertTrue(app.buttons["settings.done"].waitForExistence(timeout: 5))
        let appearance = app.buttons["Dark"]
        for _ in 0..<5 where !appearance.isHittable { app.swipeUp() }
        snap("1-settings-open-light")

        appearance.tap()
        waitForBoardStyle("dark", "Dark must restyle the board while Settings is open")
        snap("2-dark-live")

        app.buttons["Light"].tap()
        waitForBoardStyle("light", "Light must restyle the board while Settings is open")
        snap("3-light-live")

        // System follows the device setting, including after having been Dark.
        app.buttons["Dark"].tap()
        waitForBoardStyle("dark", "Dark again")
        XCUIDevice.shared.appearance = .dark
        app.buttons["System"].tap()
        waitForBoardStyle("dark", "System follows a dark device")
        snap("4-system-device-dark")
        XCUIDevice.shared.appearance = .light
        waitForBoardStyle("light", "System follows the device back to light")
        snap("5-system-device-light")

        // The choice survives closing Settings.
        app.buttons["Dark"].tap()
        waitForBoardStyle("dark", "Dark before Done")
        app.buttons["settings.done"].tap()
        XCTAssertTrue(app.buttons["settingsButton"].waitForExistence(timeout: 5))
        waitForBoardStyle("dark", "board keeps Dark after Done")
        snap("6-after-done-dark")

        // Leave System stored: the preference lives in the app's UserDefaults, which the unit-test host
        // (the Duo snapshot tests) shares on the same simulator.
        app.buttons["settingsButton"].tap()
        XCTAssertTrue(app.buttons["settings.done"].waitForExistence(timeout: 5))
        for _ in 0..<5 where !app.buttons["System"].isHittable { app.swipeUp() }
        app.buttons["System"].tap()
        app.buttons["settings.done"].tap()
    }
}
