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
}
