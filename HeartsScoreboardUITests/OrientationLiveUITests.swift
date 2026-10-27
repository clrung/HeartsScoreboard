import XCTest

/// Phase 4 live check: launches the demo app in both orientations and scenarios and checks the stacked
/// (portrait) vs side-by-side (landscape) iPad layouts. Screenshots go to $LIVE_SHOT_DIR when set.
final class OrientationLiveUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func shot(_ name: String) {
        Thread.sleep(forTimeInterval: 0.8)
        let image = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        if let dir = ProcessInfo.processInfo.environment["LIVE_SHOT_DIR"], !dir.isEmpty {
            try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            try? image.pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
        }
    }

    private func launch(_ scenario: String, dark: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-screenshotDemo", "-screenshotScenario", scenario, "-screenshotAppearance", dark ? "dark" : "light"]
        app.launch()
        XCTAssertTrue(app.buttons["settingsButton"].waitForExistence(timeout: 15))
        return app
    }

    func testOrientationsAndScenarios() throws {
        guard UIDevice.current.userInterfaceIdiom == .pad else { return }
        let device = XCUIDevice.shared
        defer { device.orientation = .portrait }
        for scenario in ["early", "long"] {
            for dark in [false, true] {
                let app = launch(scenario, dark: dark)
                let tag = "\(scenario)-\(dark ? "dark" : "light")"
                device.orientation = .landscapeLeft
                Thread.sleep(forTimeInterval: 1)
                shot("live-ipad-landscape-\(tag)")
                let landscapeScoreboard = app.otherElements["pendingRow"].exists || app.staticTexts["emptyRoundsLabel"].exists
                XCTAssertTrue(landscapeScoreboard, "pending row visible in landscape")
                device.orientation = .portrait
                Thread.sleep(forTimeInterval: 1)
                shot("live-ipad-portrait-\(tag)")
                // Stacked: the entry card sits below the scoreboard and spans (nearly) the full width.
                let submit = app.buttons["roundInput.submit"]
                XCTAssertTrue(submit.waitForExistence(timeout: 5))
                let window = app.windows.firstMatch.frame
                XCTAssertGreaterThan(submit.frame.width, window.width * 0.8, "Submit spans the stacked card")
                let firstRow = app.otherElements["roundInput.row.0"]
                if firstRow.exists { XCTAssertGreaterThan(firstRow.frame.width, window.width * 0.8) }
                // Portrait: Submit is on screen (pinned footer) and not under the keyboard/overflowing.
                XCTAssertLessThanOrEqual(submit.frame.maxY, window.maxY)
                app.terminate()
            }
        }
    }
}
