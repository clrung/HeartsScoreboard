import XCTest
@testable import HeartsScoreboard

@MainActor
final class LeaderIndicatorTests: XCTestCase {
    private func makeModel(endingScore: Int = 100) -> GameViewModel {
        var settings = GameSettings()
        settings.endingScore = endingScore
        let model = GameViewModel(initialState: SyncableState(game: HeartsGame(players: [
            .init(id: UUID(), name: "A"), .init(id: UUID(), name: "B"),
            .init(id: UUID(), name: "C"), .init(id: UUID(), name: "D")
        ]), settings: settings, firstDealerIndex: 0))
        model.persistsToCloud = false
        return model
    }

    private func addRound(_ model: GameViewModel, _ points: [Int]) {
        let ids = model.game.players.map(\.id)
        model.addHand(pointsByPlayerID: Dictionary(uniqueKeysWithValues: zip(ids, points)))
    }

    func testNoLeaderOrHighestScorerBeforeFirstRound() {
        let model = makeModel()
        XCTAssertTrue(model.leadingPlayerIDs.isEmpty)
        XCTAssertTrue(model.highestScorerIDs.isEmpty)
        XCTAssertTrue(model.leadingPlayerNames.isEmpty)
    }

    func testLeaderIsLowestTotalAndTiesAllLead() {
        let model = makeModel()
        let ids = model.game.players.map(\.id)
        addRound(model, [10, 0, 0, 16])
        XCTAssertEqual(model.leadingPlayerIDs, [ids[1], ids[2]])
        XCTAssertEqual(model.leadingPlayerNames, ["B", "C"])
        addRound(model, [0, 5, 0, 0])
        XCTAssertEqual(model.leadingPlayerIDs, [ids[2]])
    }

    func testHighestScorerIDsIncludeTies() {
        let model = makeModel()
        let ids = model.game.players.map(\.id)
        addRound(model, [13, 0, 13, 0])
        XCTAssertEqual(model.highestScorerIDs, [ids[0], ids[2]])
    }

    func testPointsRemainingAndNeverNegative() {
        let model = makeModel(endingScore: 50)
        let ids = model.game.players.map(\.id)
        addRound(model, [26, 0, 0, 0])
        XCTAssertEqual(model.pointsRemaining(for: ids[0]), 24)
        XCTAssertEqual(model.pointsRemaining(for: ids[1]), 50)
        addRound(model, [26, 0, 0, 0])
        XCTAssertEqual(model.pointsRemaining(for: ids[0]), 0)
    }

    func testProgressFractionIsClampedToOne() {
        let model = makeModel(endingScore: 50)
        let ids = model.game.players.map(\.id)
        XCTAssertEqual(model.progress(for: ids[0]), 0, accuracy: 0.0001)
        addRound(model, [25, 0, 0, 0])
        XCTAssertEqual(model.progress(for: ids[0]), 0.5, accuracy: 0.0001)
        addRound(model, [26, 0, 0, 0])
        XCTAssertEqual(model.progress(for: ids[0]), 1, accuracy: 0.0001)
    }

    func testPointsToGoOnlyForHighestScorerAndHiddenWhenGameOver() {
        let model = makeModel(endingScore: 50)
        let ids = model.game.players.map(\.id)
        XCTAssertNil(model.pointsToGo(for: ids[0]))
        addRound(model, [20, 5, 0, 0])
        XCTAssertEqual(model.pointsToGo(for: ids[0]), 30)
        XCTAssertNil(model.pointsToGo(for: ids[1]))
        addRound(model, [30, 0, 0, 0])
        XCTAssertTrue(model.isGameOver)
        XCTAssertNil(model.pointsToGo(for: ids[0]))
    }
}
