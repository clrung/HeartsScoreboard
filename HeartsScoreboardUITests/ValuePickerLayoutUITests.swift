import XCTest

/// Exercises the six-player picker and captures its rounded-edge clearance for visual review.
/// The hosting-size regression in IPadLayoutSnapshotTests guards against compressed side padding.
final class ValuePickerLayoutUITests: XCTestCase {
    func testSixPlayerPopoverShowsAndSelectsEdgeValues() throws {
        let app = XCUIApplication()
        let env = ProcessInfo.processInfo.environment
        let appearance = env["CHIP_APPEARANCE"] ?? "light"
        app.launchArguments = ["-screenshotDemo", "-screenshotPlayerCount", "6", "-screenshotAppearance", appearance]
        app.launch()

        let nextRound = app.buttons["nextRoundButton"]
        if nextRound.waitForExistence(timeout: 5), nextRound.isHittable {
            nextRound.tap()
        }

        let well = app.buttons["roundInput.value.Ben"]
        XCTAssertTrue(well.waitForExistence(timeout: 10))
        if !well.isHittable { app.swipeUp() }
        XCTAssertTrue(well.isHittable)
        well.tap()

        let picker = app.descendants(matching: .any)["roundInput.valuePicker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 10), "value picker did not appear")
        let options = ["0", "5", "24", "26"].map { app.buttons["roundInput.valueOption.\($0)"] }
        for option in options {
            XCTAssertTrue(option.waitForExistence(timeout: 5), "missing corner option \(option.identifier)")
            XCTAssertTrue(option.isHittable)
        }

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "value-picker-six-player"
        attachment.lifetime = .keepAlways
        add(attachment)

        if let shotDir = env["SHOT_DIR"], !shotDir.isEmpty {
            try FileManager.default.createDirectory(atPath: shotDir, withIntermediateDirectories: true)
            try app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: shotDir).appendingPathComponent("value-picker-\(UIDevice.current.userInterfaceIdiom == .pad ? "ipad" : "iphone")-\(appearance).png"))
        }
        if let holdSeconds = env["HOLD_PICKER_SECONDS"], let seconds = TimeInterval(holdSeconds), seconds > 0 {
            Thread.sleep(forTimeInterval: seconds)
        }

        options[3].tap()
        XCTAssertEqual(well.value as? String, "26 points")
    }
}
