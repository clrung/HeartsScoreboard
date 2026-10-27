import XCTest
import SwiftUI
import UIKit
@testable import HeartsScoreboard

@MainActor
final class ResultCardTests: XCTestCase {
    private func completed(_ names: [String], totals: [Int], rounds: Int = 3) -> CompletedGame {
        let players = names.map { HeartsGame.Player(id: UUID(), name: $0) }
        var hands: [HeartsGame.Hand] = []
        for r in 0..<rounds {
            var pts: [UUID: Int] = [:]
            for (i, p) in players.enumerated() { pts[p.id] = r == 0 ? totals[i] : 0 }
            hands.append(.init(id: UUID(), pointsByPlayerID: pts, notes: "", createdAt: Date()))
        }
        return CompletedGame(game: HeartsGame(players: players, hands: hands), settings: GameSettings())
    }

    func testOrderingAndRanksWithTies() {
        let d = ResultCardData(completed: completed(["A", "B", "C", "D", "E"], totals: [100, -4, 20, -4, 20]))
        XCTAssertEqual(d.rows.map(\.name), ["B", "D", "C", "E", "A"])
        XCTAssertEqual(d.rows.map(\.rank), [1, 1, 3, 3, 5])
        XCTAssertEqual(d.winnerNames, ListFormatter.localizedString(byJoining: ["B", "D"]))
        XCTAssertEqual(d.winnerLabel, "Winners")
        XCTAssertEqual(d.winningScore, -4)
    }

    func testSingleWinnerAndRounds() {
        let d = ResultCardData(completed: completed(["A", "B"], totals: [50, 10], rounds: 4))
        XCTAssertEqual(d.winnerNames, "B")
        XCTAssertEqual(d.winnerLabel, "Winner")
        XCTAssertEqual(d.roundsText, "4 rounds")
        XCTAssertEqual(d.series.count, 2)
        XCTAssertEqual(d.series[0], [0, 50, 50, 50, 50])
        XCTAssertEqual(ResultCardData(completed: completed(["A", "B"], totals: [1, 2], rounds: 1)).roundsText, "1 round")
    }

    func testFromStandingsHasNoRoundsLine() {
        let ps = [HeartsGame.Player(id: UUID(), name: "X"), .init(id: UUID(), name: "Y")]
        let d = ResultCardData(standings: [Standing(rank: 1, player: ps[1], total: 3),
                                           Standing(rank: 2, player: ps[0], total: 9)], date: Date())
        XCTAssertNil(d.roundsText)
        XCTAssertEqual(d.rows.map(\.name), ["Y", "X"])
        XCTAssertTrue(d.shareTitle.hasPrefix("Y"))
    }

    func testRenderedCardIsThreeTimesAndWritesPNG() throws {
        let d = ResultCardData(completed: completed(["Ace", "Deuce", "Trey", "Queen"], totals: [60, 14, 33, 14], rounds: 6))
        let image = try XCTUnwrap(ResultCardRenderer.image(for: d))
        XCTAssertEqual(image.scale, 3)
        XCTAssertEqual(image.size.width, ResultCardView.width + 24, accuracy: 1)
        let dir = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"] ?? NSTemporaryDirectory()
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        try XCTUnwrap(image.pngData()).write(to: URL(fileURLWithPath: dir).appendingPathComponent("result-card.png"))
    }

    func testSharePNGUsesStableDescriptiveFilenameAndValidPNGData() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.current
        let date = calendar.date(from: DateComponents(year: 2026, month: 10, day: 27, hour: 9, minute: 5))!
        let filename = NamedPNGFile.filename(for: date)
        XCTAssertEqual(filename, "Hearts-Scoreboard-2026-10-27-0905.png")
        XCTAssertFalse(filename.hasPrefix("."))

        let image = try XCTUnwrap(ResultCardRenderer.image(for: ResultCardData(completed: completed(["A", "B"], totals: [2, 1]))))
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = try NamedPNGFile.make(image: image, date: date, directory: dir)
        XCTAssertEqual(file.url.lastPathComponent, filename)
        let bytes = try Data(contentsOf: file.url)
        XCTAssertEqual(Array(bytes.prefix(8)), [137, 80, 78, 71, 13, 10, 26, 10])
    }


    func testFullHistoryShareRendersSixLongNamesAndOneHundredRoundsWithinPixelBudget() async throws {
        let names = ["Alexandra Longname", "Bartholomew", "Christopher", "Demetrius", "Elizabeth", "Francesca"]
        let players = names.map { HeartsGame.Player(id: UUID(), name: $0) }
        let hands = (0..<100).map { round in
            HeartsGame.Hand(
                id: UUID(),
                pointsByPlayerID: Dictionary(uniqueKeysWithValues: players.enumerated().map { ($0.element.id, ($0.offset + round) % 5) }),
                notes: "",
                createdAt: Date()
            )
        }
        let game = CompletedGame(game: HeartsGame(players: players, hands: hands), settings: GameSettings())
        let rendered = await HistoryShareRenderer.image(for: game)
        let image = try XCTUnwrap(rendered)
        XCTAssertEqual(image.size.width, 708, accuracy: 1)
        XCTAssertLessThanOrEqual(image.size.width * image.size.height * image.scale * image.scale, 32_100_000)
        if let directory = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"] {
            try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
            try XCTUnwrap(image.pngData()).write(to: URL(fileURLWithPath: directory).appendingPathComponent("history-share-100-rounds.png"))
        }

        let shortGame = CompletedGame(game: HeartsGame(players: players, hands: Array(hands.prefix(10))), settings: GameSettings())
        let shortResult = await HistoryShareRenderer.image(for: shortGame)
        let shortImage = try XCTUnwrap(shortResult)
        if let directory = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"] {
            try XCTUnwrap(shortImage.pngData()).write(to: URL(fileURLWithPath: directory).appendingPathComponent("history-share-10-rounds.png"))
        }
    }


}
