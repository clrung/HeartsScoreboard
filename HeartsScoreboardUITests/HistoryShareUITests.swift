import XCTest

/// Exercises the real file-sharing presentation from history in both appearances.
final class HistoryShareUITests: XCTestCase {
    func testHistoryShareLight() throws { try checkShare(appearance: "light") }
    func testHistoryShareDark() throws { try checkShare(appearance: "dark") }

    private func checkShare(appearance: String) throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-screenshotDemo", "-screenshotAppearance", appearance]
        app.launch()
        XCTAssertTrue(app.buttons["historyButton"].waitForExistence(timeout: 20))
        app.buttons["historyButton"].tap()
        let row = app.descendants(matching: .any)["history.row"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        Thread.sleep(forTimeInterval: 1)
        row.tap()
        let share = app.buttons["historyDetail.share"]
        XCTAssertTrue(share.waitForExistence(timeout: 10))
        let enabled = NSPredicate(format: "enabled == true")
        expectation(for: enabled, evaluatedWith: share)
        waitForExpectations(timeout: 20)
        try capture("history-\(appearance)")
        share.tap()
        let viewMore = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "View More")).firstMatch
        if viewMore.waitForExistence(timeout: 5) { viewMore.tap() }
        // Save Image is absent on the test simulator; use Save to Files to check the exported PNG filename.
        try capture("share-\(appearance)")
        let saveToFiles = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Save to Files")).firstMatch
        XCTAssertTrue(saveToFiles.waitForExistence(timeout: 10))
        saveToFiles.tap()
        // Files truncates the suggested name differently across device sizes. Check the stable
        // filename prefix here; ResultCardTests verify the PNG extension and encoding.
        let namedFile = app.descendants(matching: .any).matching(
            NSPredicate(format: "label BEGINSWITH %@ OR value BEGINSWITH %@", "Hearts-Scoreboard-", "Hearts-Scoreboard-")
        ).firstMatch
        XCTAssertTrue(namedFile.waitForExistence(timeout: 10), app.debugDescription)
        try capture("filename-\(appearance)")
    }

    private func capture(_ name: String) throws {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        if let directory = ProcessInfo.processInfo.environment["SHOT_DIR"] {
            try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
            try screenshot.pngRepresentation.write(to: URL(fileURLWithPath: directory).appendingPathComponent("\(name).png"))
        }
    }
}
