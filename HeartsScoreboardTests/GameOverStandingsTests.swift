import XCTest
@testable import HeartsScoreboard

final class GameOverStandingsTests: XCTestCase {
    private func model(totals: [Int], endingScore: Int = 100) -> GameViewModel {
        let players = totals.indices.map { HeartsGame.Player(id: UUID(), name: "P\($0 + 1)") }
        var pts: [UUID: Int] = [:]
        for (i, p) in players.enumerated() { pts[p.id] = totals[i] }
        let hand = HeartsGame.Hand(id: UUID(), pointsByPlayerID: pts, notes: "", createdAt: Date())
        let game = HeartsGame(players: players, hands: [hand])
        let m = GameViewModel(game: game, settings: GameSettings(endingScore: endingScore))
        m.persistsToCloud = false
        return m
    }

    func testLowestScoreWins() {
        let m = model(totals: [104, 40, 63, 12])
        XCTAssertTrue(m.isGameOver)
        XCTAssertEqual(m.standings.map(\.player.name), ["P4", "P2", "P3", "P1"])
        XCTAssertEqual(m.standings.map(\.rank), [1, 2, 3, 4])
        XCTAssertEqual(m.winners.map(\.player.name), ["P4"])
    }

    func testTiedWinnersShareRankAndSkipNext() {
        let m = model(totals: [101, 30, 30, 55])
        XCTAssertEqual(m.standings.map(\.player.name), ["P2", "P3", "P4", "P1"])
        XCTAssertEqual(m.standings.map(\.rank), [1, 1, 3, 4])
        XCTAssertEqual(m.winners.map(\.player.name), ["P2", "P3"])
    }

    func testTiesKeepSeatOrderAndNegativeTotalsWin() {
        let m = model(totals: [100, -4, 20, -4, 20])
        XCTAssertEqual(m.standings.map(\.player.name), ["P2", "P4", "P3", "P5", "P1"])
        XCTAssertEqual(m.standings.map(\.rank), [1, 1, 3, 3, 5])
    }

    func testAllTiedEveryoneWins() {
        let m = model(totals: [100, 100, 100])
        XCTAssertEqual(m.winners.count, 3)
        XCTAssertTrue(m.standings.allSatisfy(\.isWinner))
    }

    func testAnnouncementNamesWinnerAndScore() {
        let single = model(totals: [104, 40, 63]).gameOverAnnouncement
        XCTAssertTrue(single.contains("P2"), single)
        XCTAssertTrue(single.contains("40"), single)
        let tie = model(totals: [101, 30, 30]).gameOverAnnouncement
        XCTAssertTrue(tie.contains("P2") && tie.contains("P3") && tie.contains("30"), tie)
        XCTAssertNotEqual(single, tie)
    }

    func testFinalRoundAnnouncementIsTheResult() {
        let m = model(totals: [104, 40, 63])
        XCTAssertEqual(m.roundAddedAnnouncement, m.gameOverAnnouncement)
    }

    func testRematchKeepsPlayersAndClearsScores() {
        let m = model(totals: [104, 40, 63])
        let ids = m.game.players.map(\.id)
        m.rematch()
        XCTAssertEqual(m.game.players.map(\.id), ids)
        XCTAssertTrue(m.game.hands.isEmpty)
        XCTAssertFalse(m.isGameOver)
    }
}
