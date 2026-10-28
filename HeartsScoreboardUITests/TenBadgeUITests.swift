import XCTest

/// Regression: the 10♦ holder indicator (formerly a "−10" badge overlaid above the score, which was
/// clipped by the list cell on iPad Pro 11") must stay inside its row, left of the stepper.
final class TenBadgeUITests: XCTestCase {
    private struct NormalizedFrame {
        let x: CGFloat
        let y: CGFloat
        let width: CGFloat
        let height: CGFloat
    }

    func testMovingTenBadgeDoesNotChangePlayerRowLayout() throws {
        let players = ["Ava", "Ben", "Cleo", "Drew", "Alexandra", "Frankie"]
        let app = XCUIApplication()
        let appearance = ProcessInfo.processInfo.environment["CHIP_APPEARANCE"] ?? "light"
        app.launchArguments = ["-screenshotDemo", "-screenshotTenRule", "-screenshotPlayerCount", "6",
                               "-screenshotAppearance", appearance]
        app.launch()
        if app.buttons["nextRoundButton"].waitForExistence(timeout: 15), app.buttons["nextRoundButton"].isHittable {
            app.buttons["nextRoundButton"].tap()
        }
        XCTAssertTrue(app.buttons["roundInput.decrease.Ava"].waitForExistence(timeout: 10))

        func captureLayout(_ state: String) throws -> [String: [String: NormalizedFrame]] {
            var measurements: [String: [String: NormalizedFrame]] = [:]
            let firstRow = app.descendants(matching: .any)["roundInput.row.0"]
            XCTAssertTrue(firstRow.waitForExistence(timeout: 5), "missing first player row")
            let origin = firstRow.frame.origin
            func normalized(_ frame: CGRect) -> NormalizedFrame {
                NormalizedFrame(x: frame.minX - origin.x, y: frame.minY - origin.y,
                                width: frame.width, height: frame.height)
            }
            for (index, name) in players.enumerated() {
                let row = app.descendants(matching: .any)["roundInput.row.\(index)"]
                let playerName = row.staticTexts.matching(NSPredicate(format: "label == %@", name)).firstMatch
                let total = app.descendants(matching: .any)["playerTotal.\(name)"]
                let minus = app.buttons["roundInput.decrease.\(name)"]
                let quick = app.buttons["roundInput.quick.\(name)"]
                XCTAssertTrue(row.waitForExistence(timeout: 5), "missing row for \(name)")
                XCTAssertTrue(playerName.waitForExistence(timeout: 5), "missing name for \(name)")
                XCTAssertTrue(total.exists, "missing total for \(name)")
                XCTAssertTrue(minus.exists, "missing stepper for \(name)")
                XCTAssertTrue(quick.exists, "missing quick chip for \(name)")
                measurements[name] = [
                    "row": normalized(row.frame),
                    "name": normalized(playerName.frame),
                    "total": normalized(total.frame),
                    "stepper": normalized(minus.frame),
                    "quick": normalized(quick.frame)
                ]
            }

            if let directory = ProcessInfo.processInfo.environment["SHOT_DIR"], !directory.isEmpty {
                try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
                try app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: directory).appendingPathComponent("ten-badge-\(state)-\(appearance).png"))
            }
            return measurements
        }

        func choose(_ name: String) {
            let pickerButton = app.buttons["roundInput.ten.\(name)"]
            XCTAssertTrue(scrollToReveal(pickerButton, in: app), "10♦ picker never became tappable")
            pickerButton.tap()
            let firstRow = app.buttons["roundInput.decrease.Ava"]
            for _ in 0..<12 where !firstRow.isHittable && entryScroll(app).exists {
                entryScroll(app).swipeDown(velocity: .slow)
            }
            XCTAssertTrue(firstRow.isHittable, "could not return to the player rows")
        }

        let noHolder = try captureLayout("none")
        choose("Alexandra")
        let alexandraHolder = try captureLayout("alexandra")
        XCTAssertTrue(app.descendants(matching: .any)["roundInput.tenBadge.Alexandra"].exists)
        choose("Ava")
        let avaHolder = try captureLayout("ava")
        XCTAssertTrue(app.descendants(matching: .any)["roundInput.tenBadge.Ava"].exists)
        choose("Ava")
        let deselected = try captureLayout("deselected")
        XCTAssertFalse(app.descendants(matching: .any)["roundInput.tenBadge.Ava"].exists)

        for name in players {
            for part in ["row", "name", "total", "stepper", "quick"] {
                let reference = noHolder[name]![part]!
                for (state, layout) in [("Alexandra holder", alexandraHolder), ("Ava holder", avaHolder), ("deselected", deselected)] {
                    let actual = layout[name]![part]!
                    XCTAssertEqual(actual.x, reference.x, accuracy: 1,
                                   "\(part) moved horizontally for \(name) when 10♦ was \(state)")
                    XCTAssertEqual(actual.y, reference.y, accuracy: 1,
                                   "\(part) moved vertically for \(name) when 10♦ was \(state)")
                    XCTAssertEqual(actual.width, reference.width, accuracy: 1,
                                   "\(part) width changed for \(name) when 10♦ was \(state)")
                    XCTAssertEqual(actual.height, reference.height, accuracy: 1,
                                   "\(part) height changed for \(name) when 10♦ was \(state)")
                }
            }
        }

        if let hold = ProcessInfo.processInfo.environment["HOLD_BADGE_SECONDS"],
           let seconds = TimeInterval(hold), seconds > 0 {
            Thread.sleep(forTimeInterval: seconds)
        }
    }

    func testTenBadgeStaysInsideItsRow() {
        let app = XCUIApplication()
        app.launchArguments = ["-screenshotDemo", "-screenshotTenRule", "-screenshotAppearance", ProcessInfo.processInfo.environment["CHIP_APPEARANCE"] ?? "dark"]
        app.launch()
        if app.buttons["nextRoundButton"].waitForExistence(timeout: 15), app.buttons["nextRoundButton"].isHittable {
            app.buttons["nextRoundButton"].tap()
        }
        let ten = app.buttons["roundInput.ten.Cleo"]
        // Wait for the sheet itself, then scroll: the picker may be below the fold (lazy, not yet created),
        // so waiting on it directly just burns the timeout first.
        XCTAssertTrue(app.buttons["roundInput.decrease.Ava"].waitForExistence(timeout: 10))
        XCTAssertTrue(scrollToReveal(ten, in: app), "10♦ picker never became tappable")
        ten.tap()
        // Back to the top so the player rows (and the holder's chip) are on screen.
        let firstRow = app.buttons["roundInput.decrease.Ava"]
        for _ in 0..<12 where !firstRow.isHittable && entryScroll(app).exists { entryScroll(app).swipeDown(velocity: .slow) }
        XCTAssertTrue(firstRow.isHittable, "could not scroll back to the player rows")

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

    func testWrappedTenPickerChipDoesNotOverlapHelpText() {
        let locale = ProcessInfo.processInfo.environment["PICKER_LOCALE"]
        for appearance in ["light", "dark"] {
            let app = XCUIApplication()
            app.launchArguments = ["-screenshotDemo", "-screenshotTenRule", "-screenshotPlayerCount", "4",
                                  "-screenshotAppearance", appearance]
            if let locale {
                app.launchArguments += ["-AppleLanguages", "(\(locale))", "-AppleLocale", locale]
            }
            app.launch()
            if app.buttons["nextRoundButton"].waitForExistence(timeout: 15), app.buttons["nextRoundButton"].isHittable {
                app.buttons["nextRoundButton"].tap()
            }

            let lastPickerChip = app.buttons["roundInput.ten.Drew"]
            let help = app.descendants(matching: .any)["roundInput.ten.help"]
            XCTAssertTrue(scrollToReveal(lastPickerChip, in: app), "10♦ picker never became tappable (\(appearance))")
            XCTAssertTrue(help.waitForExistence(timeout: 5), "10♦ picker help text is missing")
            XCTAssertLessThanOrEqual(lastPickerChip.frame.maxY, help.frame.minY + 0.5,
                                     "wrapped last chip overlaps the 10♦ picker help text (\(appearance))")
            let shot = XCTAttachment(screenshot: app.screenshot())
            shot.name = "ten-picker-\(appearance)-\(locale ?? "en")"
            shot.lifetime = .keepAlways
            add(shot)
            app.terminate()
        }
    }

    /// The entry list's scroll view (sheet, or the inline card once it outgrows the pane); absent when the inline card hugs.
    private func entryScroll(_ app: XCUIApplication) -> XCUIElement { app.scrollViews["roundInput.scroll"] }

    /// On iPhone the "10♦ taken by" section is below the fold of the lazy Form.
    private func scrollToReveal(_ element: XCUIElement, in app: XCUIApplication) -> Bool {
        // Swipe the sheet's own list (a bare app.swipeUp() doesn't scroll it on narrow phones like the SE).
        for _ in 0..<12 where !element.isHittable && entryScroll(app).exists { entryScroll(app).swipeUp(velocity: .slow) }
        return element.isHittable
    }
}
