import XCTest
@testable import HeartsScoreboard

@MainActor
final class PlayerNameSuggestionsTests: XCTestCase {
    private func completed(_ names: [String]) -> CompletedGame {
        let ps = names.map { HeartsGame.Player(id: UUID(), name: $0) }
        return CompletedGame(game: HeartsGame(players: ps), settings: GameSettings())
    }

    func testMostRecentFirstUniqueAndExcludesCurrent() {
        let history = [completed(["Ann", "Bob", "Cy"]), completed(["Dee", "ann", "Bob"])]
        let s = PlayerNameSuggestions.suggestions(from: history, excluding: ["Cy"])
        XCTAssertEqual(s, ["Ann", "Bob", "Dee"])
    }

    func testSkipsPlaceholdersAndBlanks() {
        let history = [completed(["Player 1", " ", "Zed", "player 4"])]
        XCTAssertEqual(PlayerNameSuggestions.suggestions(from: history, excluding: []), ["Zed"])
    }

    func testExclusionIsCaseAndWhitespaceInsensitive() {
        let history = [completed(["Ann", "Bob"])]
        XCTAssertEqual(PlayerNameSuggestions.suggestions(from: history, excluding: ["  ANN "]), ["Bob"])
    }

    func testLimit() {
        let history = [completed(["A", "B", "C", "D"])]
        XCTAssertEqual(PlayerNameSuggestions.suggestions(from: history, excluding: [], limit: 2), ["A", "B"])
    }

    func testUseSuggestedFillsPlaceholderThenAdds() {
        let ps = ["Player 1", "Bob", "Cy"].map { HeartsGame.Player(id: UUID(), name: $0) }
        let m = GameViewModel(initialState: SyncableState(game: HeartsGame(players: ps), settings: GameSettings(), firstDealerIndex: 0))
        m.persistsToCloud = false
        XCTAssertTrue(m.useSuggestedPlayerName("Ann"))
        XCTAssertEqual(m.game.players.map(\.name), ["Ann", "Bob", "Cy"])
        XCTAssertTrue(m.useSuggestedPlayerName("Dee"))
        XCTAssertEqual(m.game.players.map(\.name), ["Ann", "Bob", "Cy", "Dee"])
    }

    func testUseSuggestedRefusesWhenFull() {
        let ps = (1...6).map { HeartsGame.Player(id: UUID(), name: "N\($0)") }
        let m = GameViewModel(initialState: SyncableState(game: HeartsGame(players: ps), settings: GameSettings(), firstDealerIndex: 0))
        m.persistsToCloud = false
        XCTAssertFalse(m.useSuggestedPlayerName("Ann"))
        XCTAssertEqual(m.game.players.count, 6)
    }
}
