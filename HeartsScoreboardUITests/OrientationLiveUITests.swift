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

    func testIPadEarlyLightOrientations() throws { try checkIPadScenario("early", dark: false) }
    func testIPadEarlyDarkOrientations() throws { try checkIPadScenario("early", dark: true) }
    func testIPadLongLightOrientations() throws { try checkIPadScenario("long", dark: false) }
    func testIPadLongDarkOrientations() throws { try checkIPadScenario("long", dark: true) }

    private func checkIPadScenario(_ scenario: String, dark: Bool) throws {
        guard UIDevice.current.userInterfaceIdiom == .pad else { return }
        let device = XCUIDevice.shared
        defer { device.orientation = .portrait }
        let app = launch(scenario, dark: dark)
        let tag = "\(scenario)-\(dark ? "dark" : "light")"
        device.orientation = .landscapeLeft
        Thread.sleep(forTimeInterval: 1)
        shot("live-ipad-landscape-\(tag)")
        if let hold = ProcessInfo.processInfo.environment["HOLD_SHEET_SECONDS"], let seconds = Double(hold) {
            Thread.sleep(forTimeInterval: seconds)
        }
        let landscapeScoreboard = app.otherElements["pendingRow"].exists || app.staticTexts["emptyRoundsLabel"].exists
        XCTAssertTrue(landscapeScoreboard, "pending row visible in landscape")
        XCTAssertFalse(app.buttons["nextRoundButton"].exists, "iPad keeps round entry inline in landscape")
        let landscapeSubmit = app.buttons["roundInput.submit"]
        XCTAssertTrue(landscapeSubmit.waitForExistence(timeout: 5), "inline Submit stays visible in landscape")
        XCTAssertLessThan(landscapeSubmit.frame.width, app.windows.firstMatch.frame.width * 0.6,
                          "landscape Submit belongs to the right-hand pane")
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
    }

    func testPhoneLandscapeUsesFullWidthBoardAndRoundSheet() throws {
        guard UIDevice.current.userInterfaceIdiom == .phone else { return }
        let device = XCUIDevice.shared
        defer { device.orientation = .portrait }
        let env = ProcessInfo.processInfo.environment
        let appearance = env["CHIP_APPEARANCE"] ?? "light"
        let app = XCUIApplication()
        app.launchArguments = ["-screenshotDemo", "-screenshotScenario", "longnames", "-screenshotPlayerCount", "6",
                              "-screenshotAppearance", appearance]
        app.launch()

        let nextRound = app.buttons["nextRoundButton"]
        XCTAssertTrue(nextRound.waitForExistence(timeout: 15))
        let names = ["Alexandria", "Bartholomew", "Christopher", "Genevieve", "Maximilian", "Wilhelmina"]

        func capture(_ name: String) {
            guard let dir = env["LIVE_SHOT_DIR"], !dir.isEmpty else { return }
            Thread.sleep(forTimeInterval: 0.5)
            let image = XCUIScreen.main.screenshot()
            try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            try? image.pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
        }

        func assertFullWidthBoardAndOpenSheet(_ orientation: String) {
            let window = app.windows.firstMatch
            XCTAssertTrue(nextRound.isHittable, "Next Round remains available on phone in \(orientation)")
            let buttonWidthFraction: CGFloat = orientation == "landscape" ? 0.65 : 0.5
            XCTAssertGreaterThan(nextRound.frame.width, window.frame.width * buttonWidthFraction,
                                 "Next Round spans the phone width in \(orientation)")
            for name in names {
                let label = app.staticTexts[name]
                XCTAssertTrue(label.exists, "player name accessibility element \(name) remains on the board")
                XCTAssertTrue(label.isHittable, "player name \(name) is visible on the board")
            }
            capture("phone-\(orientation)-board-\(appearance)")
            if orientation == "landscape",
               let hold = env["HOLD_BOARD_SECONDS"], let seconds = Double(hold), seconds > 0 {
                Thread.sleep(forTimeInterval: seconds)
            }

            nextRound.tap()
            XCTAssertTrue(app.buttons["roundInput.decrease.Alexandria"].waitForExistence(timeout: 10),
                          "round-entry sheet opens in \(orientation)")
            let submit = app.buttons["roundInput.submit"]
            XCTAssertTrue(submit.waitForExistence(timeout: 5), "sheet Submit is available in \(orientation)")
            if orientation == "landscape" {
                let first = app.otherElements["roundInput.row.0"]
                let second = app.otherElements["roundInput.row.1"]
                XCTAssertEqual(first.frame.minY, second.frame.minY, accuracy: 2, "players share a landscape row")
                XCTAssertLessThan(first.frame.maxX, second.frame.minX, "cards have a clear gap")
                XCTAssertLessThan(submit.frame.width, window.frame.width * 0.4, "landscape Submit is compact")
                let progress = app.otherElements["roundInput.progress"]
                XCTAssertEqual(progress.frame.midY, submit.frame.midY, accuracy: 15, "progress sits beside Submit")
                app.buttons["roundInput.quick.Alexandria"].tap()
                XCTAssertEqual(app.buttons["roundInput.value.Alexandria"].value as? String, "5 points")
            } else {
                XCTAssertGreaterThan(submit.frame.width, window.frame.width * 0.5)
            }
            capture("phone-\(orientation)-sheet-\(appearance)")
            if orientation == "landscape", let hold = env["HOLD_SHEET_SECONDS"], let seconds = Double(hold) {
                Thread.sleep(forTimeInterval: seconds)
            }
            let back = app.buttons["Back"]
            XCTAssertTrue(back.waitForExistence(timeout: 5), "sheet has its standard Back control")
            back.tap()
            XCTAssertTrue(nextRound.waitForExistence(timeout: 5), "return to the scoreboard after closing the sheet")
        }

        assertFullWidthBoardAndOpenSheet("portrait")
        device.orientation = .landscapeLeft
        let deadline = Date().addingTimeInterval(10)
        while app.windows.firstMatch.frame.width <= app.windows.firstMatch.frame.height && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.1)
        }
        XCTAssertGreaterThan(app.windows.firstMatch.frame.width, app.windows.firstMatch.frame.height,
                             "wait for landscape rotation before checking layout")
        assertFullWidthBoardAndOpenSheet("landscape")
    }
}
