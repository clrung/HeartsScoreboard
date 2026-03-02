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

    func movePlayers(from source: IndexSet, to destination: Int) {
        game.players.move(fromOffsets: source, toOffset: destination)
    }

    // MARK: - Helpers

    /// True when any player's total reaches or exceeds the ending score (game over).
    var isGameOver: Bool {
        game.players.contains { game.totalPoints(for: $0.id) >= settings.endingScore }
    }

    var statusText: String {
        if isGameOver {
            let totals = game.totals()
            guard let minTotal = totals.map(\.total).min() else { return "Game over" }
            let winners = totals.filter { $0.total == minTotal }.map(\.player.name)
            if winners.count == 1, let name = winners.first {
                return "\(name) won!"
            } else {
                return "Game Over: Tie"
            }
        }
        switch game.hands.count % 3 {
        case 0:
            return "Pass to the Left"
        case 1:
            return "Pass to the Right"
        default:
            return "Hold on Tight!"
        }
    }
}

