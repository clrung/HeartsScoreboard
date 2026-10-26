import XCTest

/// Regression: the red "−10" badge over the 10♦ holder's score was offset above the row and
/// clipped by the list cell (iPad Pro 11" side-by-side layout).
final class TenBadgeUITests: XCTestCase {
    func testTenBadgeStaysInsideItsRow() {
        let app = XCUIApplication()
        app.launchArguments = ["-screenshotDemo", "-screenshotTenRule", "-screenshotAppearance", ProcessInfo.processInfo.environment["CHIP_APPEARANCE"] ?? "dark"]
        app.launch()
        if app.buttons["nextRoundButton"].waitForExistence(timeout: 15), app.buttons["nextRoundButton"].isHittable {
            app.buttons["nextRoundButton"].tap()
        }
        let ten = app.buttons["roundInput.ten.Cleo"]
        XCTAssertTrue(ten.waitForExistence(timeout: 10))
        ten.tap()

        let badge = app.staticTexts["roundInput.tenBadge.Cleo"]
        XCTAssertTrue(badge.waitForExistence(timeout: 5))
        // The row's own accessibility frame grows to include an overflowing badge, so measure against the
        // stepper's full-height (44pt) minus button: the badge must not start above it.
        let minus = app.buttons["roundInput.decrease.Cleo"]
        XCTAssertTrue(minus.exists)
        XCTAssertGreaterThanOrEqual(badge.frame.minY, minus.frame.minY - 0.5, "−10 badge pokes above its row and gets clipped")
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "round-entry-ten-badge"
        shot.lifetime = .keepAlways
        add(shot)
    }
}
