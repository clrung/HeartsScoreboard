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
        // Row 0 (Ava): type 7, down to Ben and give the Q♠, down to Cleo and take the rest (6).
        // Single digits only: typeKey calls can be >1s apart on a loaded simulator, past the two-digit buffer
        // window, so "1","3" may land as 3. The buffer itself is unit-tested (RoundEntryKeyboardTests).
        app.typeKey("7", modifierFlags: [])
        XCTAssertTrue(pendingValue(app, "Ava").contains("7"), pendingValue(app, "Ava"))
        app.typeKey(XCUIKeyboardKey.downArrow.rawValue, modifierFlags: [])
        app.typeKey("q", modifierFlags: [])
        XCTAssertTrue(pendingValue(app, "Ben").contains("13"), pendingValue(app, "Ben"))
        app.typeKey(XCUIKeyboardKey.downArrow.rawValue, modifierFlags: [])
        app.typeKey("r", modifierFlags: [])
        XCTAssertTrue(pendingValue(app, "Cleo").contains("6 points"), pendingValue(app, "Cleo"))
        XCTAssertTrue(app.buttons["roundInput.submit"].isEnabled)
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "keyboard-ready"; shot.lifetime = .keepAlways; add(shot)

        // Submit (⌘↩ can't be driven by XCUITest in the simulator; the button carries the shortcut).
        app.buttons["roundInput.submit"].tap()
        XCTAssertFalse(app.buttons["roundInput.submit"].isEnabled, "entry reset after submit")
        XCTAssertTrue(app.descendants(matching: .any)["pendingRow"].label.contains("3"), "pending row is round 3 now")

        // Selection stays on Cleo: 5, + -> 6, M -> moon (everyone else gets 26).
        app.typeKey("5", modifierFlags: [])
        app.typeKey("+", modifierFlags: [])
        XCTAssertTrue(pendingValue(app, "Cleo").contains("6 points"), pendingValue(app, "Cleo"))
        app.typeKey("m", modifierFlags: [])
        XCTAssertTrue(pendingValue(app, "Cleo").lowercased().contains("moon"), pendingValue(app, "Cleo"))
        XCTAssertTrue(pendingValue(app, "Drew").contains("26 points"), pendingValue(app, "Drew"))
        let shot2 = XCTAttachment(screenshot: app.screenshot()); shot2.name = "keyboard-moon"; shot2.lifetime = .keepAlways; add(shot2)
        // Delete/Backspace is not delivered as a key press by XCUITest; unit-tested instead.
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
