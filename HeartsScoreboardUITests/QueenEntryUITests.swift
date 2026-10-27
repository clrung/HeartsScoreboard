import XCTest

/// Q♠ stays attached to its 13 points while ownership moves, and the exact-value picker
/// cannot lower its owner's score below 13.
final class QueenEntryUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        let appearance = ProcessInfo.processInfo.environment["CHIP_APPEARANCE"] ?? "light"
        app.launchArguments = ["-screenshotDemo", "-screenshotPlayerCount", "6",
                               "-screenshotAppearance", appearance]
        app.launch()

        // On compact iPhone layouts round entry is a sheet; on iPad it is already inline.
        let nextRound = app.buttons["nextRoundButton"]
        if nextRound.waitForExistence(timeout: 10), nextRound.isHittable {
            nextRound.tap()
        }
        XCTAssertTrue(app.buttons["roundInput.quick.Ava"].waitForExistence(timeout: 15))
        return app
    }

    private func setPoints(_ value: Int, for player: String, in app: XCUIApplication) {
        let well = app.buttons["roundInput.value.\(player)"]
        XCTAssertTrue(well.waitForExistence(timeout: 5), "missing value well for \(player)")
        XCTAssertTrue(well.isHittable, "value well for \(player) is not hittable")
        well.tap()

        let option = app.buttons["roundInput.valueOption.\(value)"]
        XCTAssertTrue(option.waitForExistence(timeout: 5), "missing picker option \(value)")
        XCTAssertTrue(option.isEnabled, "picker option \(value) should be enabled")
        option.tap()
        XCTAssertEqual(well.value as? String, "\(value) points")
    }

    private func capture(_ name: String, in app: XCUIApplication) throws {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        guard let directory = ProcessInfo.processInfo.environment["SHOT_DIR"], !directory.isEmpty else { return }
        try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        let appearance = ProcessInfo.processInfo.environment["CHIP_APPEARANCE"] ?? "light"
        let device = UIDevice.current.userInterfaceIdiom == .pad ? "ipad" : "iphone"
        try app.screenshot().pngRepresentation.write(
            to: URL(fileURLWithPath: directory).appendingPathComponent("queen-\(name)-\(device)-\(appearance).png")
        )
    }

    func testQueenTransfersAndCanBeRemovedFromAValidRound() throws {
        let app = launch()
        let ava = app.buttons["roundInput.value.Ava"]
        let ben = app.buttons["roundInput.value.Ben"]
        let queenAva = app.buttons["roundInput.queen.Ava"]
        let queenBen = app.buttons["roundInput.queen.Ben"]

        // Give Ava 5 hearts and Ben 8 hearts. The Q♠ then brings the normal round to 26.
        app.buttons["roundInput.quick.Ava"].tap()
        setPoints(8, for: "Ben", in: app)
        queenAva.tap()
        XCTAssertEqual(ava.value as? String, "18 points")
        XCTAssertTrue(queenAva.isSelected, "Ava should be shown as the Q♠ owner")
        XCTAssertTrue(queenAva.isEnabled, "the owner chip must remain tappable to remove Q♠")
        XCTAssertTrue(queenBen.isEnabled, "another player must be able to take Q♠ from its current owner")
        XCTAssertEqual(app.descendants(matching: .any)["roundInput.progress"].label, "Ready",
                       "the normal 26-point round should be valid before transfer")

        // Transfer Q♠: the 13 points move, while the 5 and 8 heart points stay put.
        queenBen.tap()
        XCTAssertEqual(ava.value as? String, "5 points")
        XCTAssertEqual(ben.value as? String, "21 points")
        XCTAssertFalse(queenAva.isSelected)
        XCTAssertTrue(queenBen.isSelected)
        XCTAssertEqual(app.descendants(matching: .any)["roundInput.progress"].label, "Ready",
                       "transferring Q♠ must preserve the valid 26-point round")
        try capture("transfer", in: app)

        // Tapping the selected owner again removes exactly the Q♠ points and clears ownership.
        queenBen.tap()
        XCTAssertEqual(ben.value as? String, "8 points")
        XCTAssertFalse(queenBen.isSelected)
        XCTAssertTrue(queenAva.isEnabled, "Q♠ should be available again after removal")
    }

    func testQueenOwnerCannotPickBelowThirteen() throws {
        let app = launch()
        let queenAva = app.buttons["roundInput.queen.Ava"]
        queenAva.tap()

        XCTAssertTrue(queenAva.isSelected)
        XCTAssertFalse(app.buttons["roundInput.decrease.Ava"].isEnabled,
                       "minus must be disabled at the Q♠ owner's minimum of 13")

        app.buttons["roundInput.value.Ava"].tap()
        let minimum = app.buttons["roundInput.valueOption.13"]
        XCTAssertTrue(minimum.waitForExistence(timeout: 5))
        for value in 0..<13 {
            let option = app.buttons["roundInput.valueOption.\(value)"]
            XCTAssertTrue(option.exists, "picker option \(value) missing")
            XCTAssertFalse(option.isEnabled, "Q♠ owner must not be able to select \(value)")
        }
        for value in 13...26 {
            let option = app.buttons["roundInput.valueOption.\(value)"]
            XCTAssertTrue(option.exists, "picker option \(value) missing")
            XCTAssertTrue(option.isEnabled, "Q♠ owner should be able to select \(value)")
        }
        try capture("minimum-picker", in: app)
        minimum.tap() // selecting 13 also dismisses the compact popover reliably
        XCTAssertEqual(app.buttons["roundInput.value.Ava"].value as? String, "13 points")
    }

    func testQueenChipIsDisabledForShootTheMoon() {
        let app = launch()
        app.buttons["roundInput.queen.Ava"].tap()
        app.buttons["roundInput.moon.Ben"].tap()

        XCTAssertFalse(app.buttons["roundInput.queen.Ava"].isSelected,
                       "moon scoring clears the previous queen selection")
        XCTAssertFalse(app.buttons["roundInput.queen.Ava"].isEnabled,
                       "Q♠ cannot be transferred or removed during a moon round")
        XCTAssertFalse(app.buttons["roundInput.queen.Ben"].isEnabled,
                       "Q♠ cannot be assigned during a moon round")
    }
}
