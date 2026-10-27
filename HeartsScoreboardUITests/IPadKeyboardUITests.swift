import XCTest

/// iPad split layout: the scoreboard's pending row mirrors the entry panel, and the hardware keyboard drives it.
final class IPadKeyboardUITests: XCTestCase {
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-screenshotDemo", "-screenshotScenario", "early", "-screenshotAppearance", "light"]
        app.launch()
        return app
    }

    private func skipUnlessIPad(_ app: XCUIApplication) throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "split layout is iPad only")
        XCTAssertTrue(app.buttons["roundInput.quick.Ava"].waitForExistence(timeout: 15))
    }

    private func pendingValue(_ app: XCUIApplication, _ name: String) -> String {
        app.descendants(matching: .any)["pendingCell.\(name)"].label
    }

    func testChipsUpdateThePendingRow() throws {
        let app = launch()
        try skipUnlessIPad(app)
        XCTAssertTrue(app.descendants(matching: .any)["pendingRow"].waitForExistence(timeout: 5))
        app.buttons["roundInput.queen.Ben"].tap()
        app.buttons["roundInput.quick.Ava"].tap()
        XCTAssertTrue(pendingValue(app, "Ben").contains("13"), pendingValue(app, "Ben"))
        XCTAssertTrue(pendingValue(app, "Ava").contains("5"), pendingValue(app, "Ava"))
        app.buttons["roundInput.moon.Cleo"].tap()
        XCTAssertTrue(pendingValue(app, "Cleo").lowercased().contains("moon"), pendingValue(app, "Cleo"))
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "pending-moon"; shot.lifetime = .keepAlways; add(shot)
    }

    func testHardwareKeyboardEntersARoundAndSubmits() throws {
        let app = launch()
        try skipUnlessIPad(app)
        // Row 0 (Ava): type 13, then down to Ben and give the Q♠, down to Cleo and take the rest.
        app.typeKey("1", modifierFlags: [])
        app.typeKey("3", modifierFlags: [])
        XCTAssertTrue(pendingValue(app, "Ava").contains("13"), pendingValue(app, "Ava"))
        app.typeKey(XCUIKeyboardKey.downArrow.rawValue, modifierFlags: [])
        app.typeKey("q", modifierFlags: [])
        XCTAssertTrue(pendingValue(app, "Ben").contains("13"), pendingValue(app, "Ben"))
        XCTAssertTrue(app.buttons["roundInput.submit"].isEnabled)
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "keyboard-ready"; shot.lifetime = .keepAlways; add(shot)

        // Submit (⌘↩ can't be driven by XCUITest in the simulator; the button carries the shortcut).
        app.buttons["roundInput.submit"].tap()
        XCTAssertFalse(app.buttons["roundInput.submit"].isEnabled, "entry reset after submit")
        XCTAssertTrue(app.descendants(matching: .any)["pendingRow"].label.contains("3"), "pending row is round 3 now")

        // Selection stays on Ben: 5, + -> 6, 0 -> 0, M -> moon.
        app.typeKey("5", modifierFlags: [])
        app.typeKey("+", modifierFlags: [])
        XCTAssertTrue(pendingValue(app, "Ben").contains("6 points"), pendingValue(app, "Ben"))
        app.typeKey("0", modifierFlags: []) // Delete/Backspace is not delivered as a key press by XCUITest; unit-tested instead
        XCTAssertTrue(pendingValue(app, "Ben").contains("0 points"), pendingValue(app, "Ben"))
        app.typeKey("m", modifierFlags: [])
        XCTAssertTrue(pendingValue(app, "Ben").lowercased().contains("moon"), pendingValue(app, "Ben"))
        let shot2 = XCTAttachment(screenshot: app.screenshot()); shot2.name = "keyboard-moon"; shot2.lifetime = .keepAlways; add(shot2)
        // Tab moves the selection, R takes the rest on Cleo? (round already valid as a moon: ignored).
        app.typeKey(XCUIKeyboardKey.tab.rawValue, modifierFlags: [])
        XCTAssertTrue(pendingValue(app, "Cleo").contains("26 points"), pendingValue(app, "Cleo"))
    }

    /// The value well opens the 0...26 popover; picking 13 sets the row and the scoreboard's pending row (live, not a snapshot).
    func testValuePickerPopoverSetsExactValue() throws {
        let app = launch()
        try skipUnlessIPad(app)
        let well = app.buttons["roundInput.value.Cleo"]
        XCTAssertTrue(well.waitForExistence(timeout: 5))
        well.tap()
        let option = app.buttons["roundInput.valueOption.13"]
        XCTAssertTrue(option.waitForExistence(timeout: 5), "popover grid did not appear")
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "value-popover"; shot.lifetime = .keepAlways; add(shot)
        option.tap()
        XCTAssertFalse(option.waitForExistence(timeout: 1), "popover should dismiss after a pick")
        XCTAssertTrue(pendingValue(app, "Cleo").contains("13 points"), pendingValue(app, "Cleo"))
        XCTAssertEqual(well.value as? String, "13 points", "well value: \(String(describing: well.value))")
    }
}
