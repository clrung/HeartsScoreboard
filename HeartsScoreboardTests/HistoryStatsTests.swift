import XCTest
@testable import HeartsScoreboard

final class HistoryStatsTests: XCTestCase {
    private func completed(
        names: [String] = ["A", "B", "C", "D"],
        _ hands: [[Int]],
        tenHolders: [Int?] = [],
        settings: GameSettings = GameSettings(),
        at date: Date = Date()
    ) -> CompletedGame {
        let players = names.map { HeartsGame.Player(id: UUID(), name: $0) }
        let hs = hands.enumerated().map { i, scores in
            HeartsGame.Hand(
                id: UUID(),
                pointsByPlayerID: Dictionary(uniqueKeysWithValues: zip(players.map(\.id), scores)),
                notes: "", createdAt: date,
                tenOfDiamondsPlayerID: i < tenHolders.count ? tenHolders[i].map { players[$0].id } : nil
            )
        }
        return CompletedGame(finishedAt: date, game: HeartsGame(players: players, hands: hs), settings: settings)
    }

    func testCumulativeSeriesStartsAtZeroAndAccumulates() {
        let c = completed([[13, 13, 0, 0], [0, 5, 21, 0], [-10, 0, 26, 10]])
        let s = c.cumulativeSeries
        XCTAssertEqual(s.map(\.name), ["A", "B", "C", "D"])
        XCTAssertEqual(s[0].points, [0, 13, 13, 3])
        XCTAssertEqual(s[1].points, [0, 13, 18, 18])
        XCTAssertEqual(s[2].points, [0, 0, 21, 47])
        XCTAssertEqual(s[3].points, [0, 0, 0, 10])
        // Last point equals the final total.
        XCTAssertEqual(s.map { $0.points.last }, c.game.totals().map { $0.total })
    }

    func testCumulativeSeriesWithNoHands() {
        XCTAssertEqual(completed([]).cumulativeSeries.map(\.points), [[0], [0], [0], [0]])
    }

    func testBiggestHandPicksHighestAndFirstOnTie() {
        let c = completed([[13, 13, 0, 0], [0, 20, 6, 0], [20, 0, 0, 6]])
        XCTAssertEqual(c.biggestHand, CompletedGame.BiggestHand(playerName: "B", points: 20, round: 2))
        XCTAssertNil(completed([]).biggestHand)
    }

    func testMoonCountCountsHandsNotPlayers() {
        let c = completed([[13, 13, 0, 0], [0, 26, 26, 26], [26, 0, 26, 26], [10, 10, 3, 3]])
        XCTAssertEqual(c.moonCount, 2)
    }

    func testTenOfDiamondsCount() {
        let c = completed([[13, 3, 0, 0], [0, 13, 13, 0], [13, 13, 0, 0]],
                          tenHolders: [1, nil, 2],
                          settings: GameSettings(tenOfDiamondsMinus10: true))
        XCTAssertEqual(c.tenOfDiamondsCount, 2)
        XCTAssertEqual(completed([[13, 13, 0, 0]]).tenOfDiamondsCount, 0)
    }

    func testWinnerNamesAndHeroText() {
        let solo = completed([[10, 0, 16, 0], [20, 5, 1, 0]])
        XCTAssertEqual(solo.winnerNames, ["D"])
        XCTAssertEqual(solo.heroText, "D won with 0")
        let tie = completed([[13, 0, 0, 13]])
        XCTAssertEqual(tie.winnerNames, ["B", "C"])
        XCTAssertTrue(tie.heroText.hasSuffix("tied with 0"), tie.heroText)
        XCTAssertTrue(tie.heroText.contains("B") && tie.heroText.contains("C"))
    }

    func testRuleSummaryReflectsSettings() {
        let plain = completed([[13, 13, 0, 0]], settings: GameSettings(endingScore: 75, shootMoonPreference: .add26))
        XCTAssertEqual(plain.ruleSummary, "Ends at 75 · Moon adds 26 to others")
        let rich = completed([[13, 13, 0, 0]], settings: GameSettings(shootMoonPreference: .subtract26, tenOfDiamondsMinus10: true))
        XCTAssertEqual(rich.ruleSummary, "Ends at 100 · Moon subtracts 26 from shooter · 10♦ = −10")
    }

    // MARK: Leaderboard

    func testRecordsWinsTiesWinPercentAverageAndMoons() {
        // Game 1: A=0 wins. Game 2: A and B tie for lowest (0). Game 3: A moon-shoots but D wins? A: 0,26,26,26 -> A lowest.
        let g1 = completed([[13, 13, 0, 0]], at: Date(timeIntervalSince1970: 1))               // C,D win (0)
        let g2 = completed([[0, 0, 13, 13]], at: Date(timeIntervalSince1970: 2))               // A,B win
        let g3 = completed([[0, 26, 26, 26]], at: Date(timeIntervalSince1970: 3))              // A moon, A wins
        let r = [g1, g2, g3].playerRecords
        let a = try! XCTUnwrap(r.first { $0.name == "A" })
        XCTAssertEqual(a.gamesPlayed, 3)
        XCTAssertEqual(a.wins, 2)
        XCTAssertEqual(a.winPercent, 200.0 / 3.0, accuracy: 0.001)
        XCTAssertEqual(a.averageScore, 13.0 / 3.0, accuracy: 0.001)   // (13 + 0 + 0) / 3
        XCTAssertEqual(a.moons, 1)
        let d = try! XCTUnwrap(r.first { $0.name == "D" })
        XCTAssertEqual(d.wins, 1)
        XCTAssertEqual(d.moons, 0)
        XCTAssertEqual(d.averageScore, (0.0 + 13 + 26) / 3, accuracy: 0.001)
        XCTAssertEqual(r.first?.name, "A", "most wins first")
    }

    func testNamesMatchCaseInsensitivelyAndTrimmed() {
        let g1 = completed(names: ["Alice", "Bob"], [[0, 26]], at: Date(timeIntervalSince1970: 1))
        let g2 = completed(names: ["  alice ", "BOB"], [[26, 0]], at: Date(timeIntervalSince1970: 2))
        let r = [g1, g2].playerRecords
        XCTAssertEqual(r.count, 2)
        let alice = try! XCTUnwrap(r.first { $0.id == "alice" })
        XCTAssertEqual(alice.gamesPlayed, 2)
        XCTAssertEqual(alice.wins, 1)
        XCTAssertEqual(alice.name, "alice", "display name comes from the most recent game, trimmed")
    }

    func testBlankNamesSkippedAndEmptyHistory() {
        XCTAssertTrue([CompletedGame]().playerRecords.isEmpty)
        let c = completed(names: ["  ", "Bob"], [[26, 0]])
        XCTAssertEqual([c].playerRecords.map(\.name), ["Bob"])
    }

    func testZeroGamesRecordHasZeroRates() {
        let rec = PlayerRecord(id: "x", name: "x", gamesPlayed: 0, wins: 0, totalScore: 0, moons: 0)
        XCTAssertEqual(rec.winPercent, 0)
        XCTAssertEqual(rec.averageScore, 0)
    }

    func testOrderingTiebreaksOnWinPercent() {
        // X: 1 win of 1 (100%), Y: 1 win of 2 (50%), equal wins -> X first.
        let g1 = completed(names: ["X", "Y"], [[0, 26]], at: Date(timeIntervalSince1970: 1))
        let g2 = completed(names: ["Y", "Z"], [[0, 26]], at: Date(timeIntervalSince1970: 2))
        let r = [g1, g2].playerRecords
        XCTAssertEqual(r.map(\.name).prefix(2), ["X", "Y"])
    }
}
