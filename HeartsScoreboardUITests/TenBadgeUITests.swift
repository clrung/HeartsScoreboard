import XCTest

/// Regression: the 10♦ holder indicator (formerly a "−10" badge overlaid above the score, which was
/// clipped by the list cell on iPad Pro 11") must stay inside its row, left of the stepper.
final class TenBadgeUITests: XCTestCase {
    func testTenBadgeStaysInsideItsRow() {
        let app = XCUIApplication()
        app.launchArguments = ["-screenshotDemo", "-screenshotTenRule", "-screenshotAppearance", ProcessInfo.processInfo.environment["CHIP_APPEARANCE"] ?? "dark"]
        app.launch()
        if app.buttons["nextRoundButton"].waitForExistence(timeout: 15), app.buttons["nextRoundButton"].isHittable {
            app.buttons["nextRoundButton"].tap()
        }
        let ten = app.buttons["roundInput.ten.Cleo"]
        XCTAssertTrue(ten.waitForExistence(timeout: 10) || scrollToReveal(ten, in: app))
        ten.tap()
        // Back to the top so the player rows (and the holder's chip) are on screen.
        for _ in 0..<3 where app.buttons["roundInput.decrease.Ava"].isHittable == false { app.swipeDown() }

        let badge = app.descendants(matching: .any)["roundInput.tenBadge.Cleo"]
        XCTAssertTrue(badge.waitForExistence(timeout: 5))
        // The row's own accessibility frame grows to include an overflowing badge, so measure against the
        // stepper's full-height (44pt) minus button: the badge must not start above it.
        let minus = app.buttons["roundInput.decrease.Cleo"]
        XCTAssertTrue(minus.exists)
        XCTAssertGreaterThanOrEqual(badge.frame.minY, minus.frame.minY - 0.5, "10♦ chip pokes above its row and gets clipped")
        XCTAssertLessThanOrEqual(badge.frame.maxX, minus.frame.minX + 0.5, "10♦ chip should sit left of the stepper")
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "round-entry-ten-badge"
        shot.lifetime = .keepAlways
        add(shot)
    }

    /// On iPhone the "10♦ taken by" section is below the fold of the lazy Form.
    private func scrollToReveal(_ element: XCUIElement, in app: XCUIApplication) -> Bool {
        for _ in 0..<4 where !element.isHittable { app.swipeUp() }
        return element.isHittable
    }
}
