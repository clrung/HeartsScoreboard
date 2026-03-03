import Foundation
import Observation

enum ShootMoonPreference: String, CaseIterable, Identifiable, Codable {
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

struct GameSettings: Codable {
    var endingScore: Int = 100
    var shootMoonPreference: ShootMoonPreference = .add26
}

@Observable
final class GameViewModel {
    var game: HeartsGame
    var settings: GameSettings
    /// Index of the player who deals first (round 1). Dealer rotates each round. Stored on VM so UI updates when changed in Settings.
    var firstDealerIndex: Int = 0

    init(
        game: HeartsGame = HeartsGame(players: [
            .init(id: UUID(), name: "Ace"),
            .init(id: UUID(), name: "Deuce"),
            .init(id: UUID(), name: "Trey"),
            .init(id: UUID(), name: "Queen")
        ]),
        settings: GameSettings = GameSettings(),
        firstDealerIndex: Int = 0
    ) {
        self.game = game
        self.settings = settings
        self.firstDealerIndex = firstDealerIndex
    }

    /// Create from iCloud-synced state.
    convenience init(initialState: SyncableState?) {
        if let state = initialState {
            self.init(game: state.game, settings: state.settings, firstDealerIndex: state.firstDealerIndex)
        } else {
            self.init()
        }
    }

    /// Apply state received from iCloud (e.g. after sync from another device).
    func applySyncedState(_ state: SyncableState) {
        game = state.game
        settings = state.settings
        self.firstDealerIndex = state.firstDealerIndex
    }

    func persistToCloud() {
        CloudSyncManager.shared.save(SyncableState(game: game, settings: settings, firstDealerIndex: firstDealerIndex))
    }

    // MARK: - Game flow

    func newGame() {
        game.hands = []
        persistToCloud()
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
        persistToCloud()
    }

    func deleteHands(at offsets: IndexSet) {
        game.hands.remove(atOffsets: offsets)
        persistToCloud()
    }

    func removeLastHand() {
        guard !game.hands.isEmpty else { return }
        game.hands.removeLast()
        persistToCloud()
    }

    func movePlayers(from source: IndexSet, to destination: Int) {
        let currentDealerID: UUID? = {
            guard game.players.indices.contains(firstDealerIndex) else { return nil }
            return game.players[firstDealerIndex].id
        }()

        game.players.move(fromOffsets: source, toOffset: destination)

        if let dealerID = currentDealerID,
           let newIndex = game.players.firstIndex(where: { $0.id == dealerID }) {
            firstDealerIndex = newIndex
        }

        persistToCloud()
    }

    func addPlayer() {
        guard game.players.count < 6 else { return }
        let defaultName = "Player \(game.players.count + 1)"
        game.players.append(.init(id: UUID(), name: defaultName))
        persistToCloud()
    }

    func deletePlayers(at offsets: IndexSet) {
        guard !offsets.isEmpty else { return }
        let currentCount = game.players.count
        let maxRemovable = max(0, currentCount - 3)
        guard maxRemovable > 0 else { return }

        let sorted = offsets.sorted()
        let indicesToRemove = Array(sorted.prefix(maxRemovable))
        game.players.remove(atOffsets: IndexSet(indicesToRemove))

        if firstDealerIndex >= game.players.count {
            firstDealerIndex = max(0, game.players.count - 1)
        }

        persistToCloud()
    }

    /// Dealer for the next round (index into players). Advances after each submitted round.
    var currentDealerIndex: Int {
        let n = game.players.count
        guard n > 0 else { return 0 }
        return (firstDealerIndex + game.hands.count) % n
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

