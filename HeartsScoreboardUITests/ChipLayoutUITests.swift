import XCTest

/// Regression: the "+remaining" chip ("+26" on an empty round) was truncated to "+…" on narrow rows.
final class ChipLayoutUITests: XCTestCase {
    func testRemainingChipIsWideEnoughForFullText() {
        let app = XCUIApplication()
        app.launchArguments = ["-screenshotDemo", "-screenshotAppearance", ProcessInfo.processInfo.environment["CHIP_APPEARANCE"] ?? "light"]
        app.launch()
        if app.buttons["nextRoundButton"].waitForExistence(timeout: 15), app.buttons["nextRoundButton"].isHittable {
            app.buttons["nextRoundButton"].tap()
        }
        let chip = app.buttons["roundInput.remaining.Ava"]
        XCTAssertTrue(chip.waitForExistence(timeout: 10))
        // "+26" in 15pt semibold is ~27pt; with 10pt padding each side the capsule needs >= ~47pt (the old 44pt chip left only 20pt of text room).
        XCTAssertGreaterThanOrEqual(chip.frame.width, 46, "remaining chip too narrow for \"+26\"")
        // Same width as the quick chip above it (consistent 2x2 grid).
        XCTAssertEqual(chip.frame.width, app.buttons["roundInput.queen.Ava"].frame.width, accuracy: 1)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "round-entry-empty"
        shot.lifetime = .keepAlways
        add(shot)
    }
}
