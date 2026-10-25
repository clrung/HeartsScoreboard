import XCTest
@testable import HeartsScoreboard

final class CompletedGameSummaryTests: XCTestCase {
    private let ids = (0..<4).map { _ in UUID() }

    private func makeCompleted(_ hands: [[Int]]) -> CompletedGame {
        let names = ["A", "B", "C", "D"]
        let players = zip(ids, names).map { HeartsGame.Player(id: $0, name: $1) }
        let hs = hands.map { scores in
            HeartsGame.Hand(
                id: UUID(),
                pointsByPlayerID: Dictionary(uniqueKeysWithValues: zip(ids, scores)),
                notes: "",
                createdAt: Date()
            )
        }
        return CompletedGame(game: HeartsGame(players: players, hands: hs), settings: GameSettings())
    }

    func testSortedResultsOrdersLowestFirst() {
        let c = makeCompleted([[10, 0, 16, 0], [20, 5, 1, 0]])
        XCTAssertEqual(c.sortedResults.map(\.name), ["D", "B", "C", "A"])
        XCTAssertEqual(c.sortedResults.map(\.total), [0, 5, 17, 30])
        XCTAssertEqual(c.winningScore, 0)
    }

    func testTiesKeepSeatingOrder() {
        let c = makeCompleted([[13, 0, 0, 13]])
        XCTAssertEqual(c.sortedResults.map(\.name), ["B", "C", "A", "D"])
        XCTAssertEqual(c.winningScore, 0)
    }

    func testRoundCountAndMoonDetection() {
        let noMoon = makeCompleted([[26 - 13, 13, 0, 0], [0, 0, 13, 13]])
        XCTAssertEqual(noMoon.roundCount, 2)
        XCTAssertFalse(noMoon.hadMoonShot)

        // Shooter (A) takes 0, everyone else 26.
        let moon = makeCompleted([[13, 13, 0, 0], [0, 26, 26, 26]])
        XCTAssertTrue(moon.hadMoonShot)
    }

    func testEmptyGame() {
        let c = CompletedGame(game: HeartsGame(players: []), settings: GameSettings())
        XCTAssertTrue(c.sortedResults.isEmpty)
        XCTAssertNil(c.winningScore)
        XCTAssertEqual(c.roundCount, 0)
        XCTAssertFalse(c.hadMoonShot)
    }
}
