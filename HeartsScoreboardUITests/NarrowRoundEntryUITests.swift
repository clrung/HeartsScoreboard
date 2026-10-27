import XCTest

/// Round-entry sheet on a narrow phone (iPhone SE, 375pt) with the 10♦ rule on and a holder selected:
/// nothing may be clipped at the edges, rows must not overlap, and the stepper column must stay aligned.
/// Env: PLAYERS (4|6), CHIP_APPEARANCE (light|dark), SHOT_PREFIX (screenshot name prefix).
final class NarrowRoundEntryUITests: XCTestCase {
    func testHolderRowFitsAtNarrowWidth() {
        let env = ProcessInfo.processInfo.environment
        let players = env["PLAYERS"] ?? "4"
        let app = XCUIApplication()
        app.launchArguments = ["-screenshotDemo", "-screenshotTenRule", "-screenshotPlayerCount", players, "-screenshotTenHolder", env["HOLDER"] ?? "Ava",
                               "-screenshotAppearance", env["CHIP_APPEARANCE"] ?? "light"]
        app.launch()
        if app.buttons["nextRoundButton"].waitForExistence(timeout: 15), app.buttons["nextRoundButton"].isHittable {
            app.buttons["nextRoundButton"].tap()
        }
        let holder = env["HOLDER"] ?? "Ava"
        func snap(_ tag: String) {
            guard let dir = env["SHOT_DIR"] else { return }
            try? app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(dir)/\(env["SHOT_PREFIX"] ?? "narrow")-\(tag).png"))
        }
        snap("0-open")
        // The sheet opens at a medium detent; pull it to full height so the whole form is reachable.
        let win = app.windows.firstMatch
        XCTAssertTrue(app.buttons["roundInput.decrease.Ava"].waitForExistence(timeout: 10))
        win.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.62))
            .press(forDuration: 0.1, thenDragTo: win.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.07)))
        snap("0b-expanded")
        let holderBadge = app.descendants(matching: .any)["roundInput.tenBadge.\(holder)"]
        func inView() -> Bool {
            holderBadge.exists && holderBadge.frame.minY > 90 && holderBadge.frame.maxY < win.frame.maxY - 110
        }
        // The drag may have scrolled the form too: tap the status bar to return to the first row.
        win.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.012)).tap()
        sleep(1)
        for _ in 0..<40 where !inView() { scrollSurface(app).swipeUp(velocity: .slow) }
        snap("0c-found")
        let badge = app.descendants(matching: .any)["roundInput.tenBadge.\(holder)"]
        XCTAssertTrue(badge.waitForExistence(timeout: 10))
        let screen = app.windows.firstMatch.frame
        let names = ["Ava", "Ben", "Cleo", "Drew", "Alexandra", "Frankie"].prefix(Int(players) ?? 4)
        var stepperX: CGFloat?
        var lastMaxY: CGFloat = -.infinity
        var measuredRows = 0
        for name in names {
            let minus = app.buttons["roundInput.decrease.\(name)"]
            guard minus.exists, minus.isHittable else { continue }
            measuredRows += 1
            // Accessibility sizes stack each row vertically on purpose, so only compare the one-line layout.
            if env["AX"] != "1" {
                if let x = stepperX {
                    XCTAssertEqual(minus.frame.minX, x, accuracy: 1, "stepper column drifts on \(name)'s row")
                } else { stepperX = minus.frame.minX }
            }
            XCTAssertGreaterThanOrEqual(minus.frame.minY, lastMaxY - 0.5, "rows overlap at \(name)")
            lastMaxY = minus.frame.maxY
            XCTAssertLessThanOrEqual(minus.frame.maxX, screen.maxX - 8, "controls clipped on trailing edge")
        }
        XCTAssertGreaterThanOrEqual(measuredRows, 2, "too few rows on screen to check stepper alignment")
        XCTAssertGreaterThanOrEqual(badge.frame.minX, 8, "10♦ chip clipped on leading edge")
        let minus = app.buttons["roundInput.decrease.\(holder)"]
        XCTAssertLessThanOrEqual(badge.frame.maxX, minus.frame.minX + 0.5, "10♦ chip overlaps stepper")
        snap("1-holder")
        var sawLongName = false
        // name -> true when that row stacks its total under the name.
        var stackedByName: [String: Bool] = [:]
        func checkNames() {
            for name in names {
                if env["AX"] != "1", name != holder,
                   let nameText = app.staticTexts.matching(NSPredicate(format: "label == %@", name)).allElementsBoundByIndex.first(where: { $0.isHittable }),
                   let total = app.descendants(matching: .any).matching(identifier: "playerTotal.\(name)").allElementsBoundByIndex.first(where: { $0.isHittable }) {
                    stackedByName[name] = abs(total.frame.midY - nameText.frame.midY) > 8
                }
                // A name must keep (nearly) all its characters: "Alexandra" truncated to "Al…" is ~30pt wide.
                // Only the sheet's own copy counts (the scoreboard behind it is not hittable).
                if name.count >= 8 {
                    let labels = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", name)).allElementsBoundByIndex
                    for label in labels where label.isHittable {
                        XCTAssertGreaterThanOrEqual(label.frame.width, 60, "\(name) is truncated")
                        sawLongName = true
                    }
                }
                let m = app.buttons["roundInput.decrease.\(name)"]
                guard m.exists, m.isHittable else { continue }
                XCTAssertLessThanOrEqual(m.frame.maxX, screen.maxX - 8, "controls clipped on trailing edge (\(name))")
            }
        }
        checkNames()
        // Walk down the list so the later rows (6 players) are captured and checked too.
        for i in 0..<3 {
            scrollSurface(app).swipeUp(velocity: .slow)
            snap("2-scroll\(i)")
            checkNames()
        }
        if env["AX"] != "1" {
            XCTAssertGreaterThanOrEqual(stackedByName.count, 2, "could not measure enough rows")
            XCTAssertEqual(Set(stackedByName.values).count, 1, "non-holder rows mix one-line and stacked layouts: \(stackedByName)")
        }
        if names.contains("Alexandra") { XCTAssertTrue(sawLongName, "never found the long-name row to check") }
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "\(env["SHOT_PREFIX"] ?? "narrow")-\(players)p"
        shot.lifetime = .keepAlways
        add(shot)
    }

    private func scrollSurface(_ app: XCUIApplication) -> XCUIElement {
        let form = app.collectionViews.firstMatch
        return form.exists ? form : app.tables.firstMatch
    }
}
