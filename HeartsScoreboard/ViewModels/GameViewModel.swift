import Foundation
import Observation

enum BoardTheme: String, CaseIterable, Identifiable {
    case light
    case green
    case dark

    var id: String { rawValue }
}

enum ShootMoonPreference: String, CaseIterable, Identifiable {
    case add26
    case subtract26

    var id: String { rawValue }

    var label: String {
        switch self {
        case .add26: return "Add 26"
        case .subtract26: return "Subtract 26"
        }
    }
}

struct GameSettings {
    var endingScore: Int = 100
    var theme: BoardTheme = .green
    var shootMoonPreference: ShootMoonPreference = .add26
}

@Observable
final class GameViewModel {
    var game: HeartsGame
    var settings: GameSettings

    init(
        game: HeartsGame = HeartsGame(players: [
            .init(id: UUID(), name: "Dad"),
            .init(id: UUID(), name: "Allie"),
            .init(id: UUID(), name: "Christopher"),
            .init(id: UUID(), name: "Mom")
        ]),
        settings: GameSettings = GameSettings()
    ) {
        self.game = game
        self.settings = settings
    }

    // MARK: - Game flow

    func newGame() {
        game.hands = []
    }

    func addHand(pointsByPlayerID: [UUID: Int]) {
        game.hands.append(
            .init(
                id: UUID(),
                pointsByPlayerID: pointsByPlayerID,
                notes: "",
                createdAt: Date()
            )
        )
    }

    func deleteHands(at offsets: IndexSet) {
        game.hands.remove(atOffsets: offsets)
    }

    // MARK: - Helpers

    var statusText: String {
        // Simple placeholder for now
        "Hold on tight!"
    }
}

