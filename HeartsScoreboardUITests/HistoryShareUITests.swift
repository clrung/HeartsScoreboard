import XCTest

/// Exercises the real file-sharing presentation from history in both appearances.
final class HistoryShareUITests: XCTestCase {
    func testHistoryShareLight() throws { try checkShare(appearance: "light") }
    func testHistoryShareDark() throws { try checkShare(appearance: "dark") }

    func testGameOverShareLight() throws { try checkShare(appearance: "light", gameOver: true) }
    func testGameOverShareDark() throws { try checkShare(appearance: "dark", gameOver: true) }

    private func checkShare(appearance: String, gameOver: Bool = false) throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-screenshotDemo", "-screenshotAppearance", appearance]
        if gameOver { app.launchArguments += ["-screenshotScenario", "over"] }
        app.launch()
        if !gameOver {
            XCTAssertTrue(app.buttons["historyButton"].waitForExistence(timeout: 20))
            app.buttons["historyButton"].tap()
            let row = app.descendants(matching: .any)["history.row"].firstMatch
            XCTAssertTrue(row.waitForExistence(timeout: 10))
            Thread.sleep(forTimeInterval: 1)
            row.tap()
        }
        let share = app.buttons[gameOver ? "gameOver.share" : "historyDetail.share"]
        let context = gameOver ? "game-over" : "history"
        XCTAssertTrue(share.waitForExistence(timeout: 20))
        let enabled = NSPredicate(format: "enabled == true")
        expectation(for: enabled, evaluatedWith: share)
        waitForExpectations(timeout: 20)
        try capture("\(context)-\(appearance)")
        share.tap()
        let viewMore = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "View More")).firstMatch
        if viewMore.waitForExistence(timeout: 5) { viewMore.tap() }
        // Save Image is absent on the test simulator; use Save to Files to check the exported PNG filename.
        try capture("\(context)-share-\(appearance)")
        let saveToFiles = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Save to Files")).firstMatch
        XCTAssertTrue(saveToFiles.waitForExistence(timeout: 10))
        saveToFiles.tap()
        // Files truncates the suggested name differently across device sizes. Check the stable
        // filename prefix here; ResultCardTests verify the PNG extension and encoding.
        let namedFile = app.descendants(matching: .any).matching(
            NSPredicate(format: "label BEGINSWITH %@ OR value BEGINSWITH %@", "Hearts-Scoreboard-", "Hearts-Scoreboard-")
        ).firstMatch
        XCTAssertTrue(namedFile.waitForExistence(timeout: 10), app.debugDescription)
        try capture("\(context)-filename-\(appearance)")
    }

    private func capture(_ name: String) throws {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        if let directory = ProcessInfo.processInfo.environment["SHOT_DIR"] {
            try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
            try screenshot.pngRepresentation.write(to: URL(fileURLWithPath: directory).appendingPathComponent("\(Int(screenshot.image.size.width))-\(name).png"))
        }
    }
}
