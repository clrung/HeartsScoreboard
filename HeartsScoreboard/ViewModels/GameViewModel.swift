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

enum AppearancePreference: String, CaseIterable, Identifiable, Codable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
}

struct GameSettings: Codable {
    var endingScore: Int = 100
    var shootMoonPreference: ShootMoonPreference = .add26
    var appearance: AppearancePreference = .system

    private enum CodingKeys: String, CodingKey {
        case endingScore
        case shootMoonPreference
        case appearance
    }

    init(
        endingScore: Int = 100,
        shootMoonPreference: ShootMoonPreference = .add26,
        appearance: AppearancePreference = .system
    ) {
        self.endingScore = endingScore
        self.shootMoonPreference = shootMoonPreference
        self.appearance = appearance
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        endingScore = try container.decodeIfPresent(Int.self, forKey: .endingScore) ?? 100
        shootMoonPreference = try container.decodeIfPresent(ShootMoonPreference.self, forKey: .shootMoonPreference) ?? .add26
        appearance = try container.decodeIfPresent(AppearancePreference.self, forKey: .appearance) ?? .system
    }
}

@Observable
final class GameViewModel {
    private let appearanceDefaultsKey = "HeartsScoreboardAppearancePreference"

    var game: HeartsGame
    var settings: GameSettings
    /// Index of the player who deals first (round 1). Dealer rotates each round. Stored on VM so UI updates when changed in Settings.
    var firstDealerIndex: Int = 0
    /// Completed games history (most recent first).
    var history: [CompletedGame] = []

    init(
        game: HeartsGame = HeartsGame(players: [
            .init(id: UUID(), name: "Ace"),
            .init(id: UUID(), name: "Deuce"),
            .init(id: UUID(), name: "Trey"),
            .init(id: UUID(), name: "Queen")
        ]),
        settings: GameSettings = GameSettings(),
        firstDealerIndex: Int = 0,
        history: [CompletedGame] = []
    ) {
        self.game = game
        self.settings = settings
        self.firstDealerIndex = firstDealerIndex
        self.history = history

        applyLocalAppearancePreference()
    }

    /// Create from iCloud-synced state.
    convenience init(initialState: SyncableState?) {
        if let state = initialState {
            self.init(
                game: state.game,
                settings: state.settings,
                firstDealerIndex: state.firstDealerIndex,
                history: state.history
            )
        } else {
            self.init()
        }
    }

    /// Apply state received from iCloud (e.g. after sync from another device).
    func applySyncedState(_ state: SyncableState) {
        game = state.game
        settings = state.settings
        self.firstDealerIndex = state.firstDealerIndex
        self.history = state.history
        applyLocalAppearancePreference()
    }

    func persistToCloud() {
        CloudSyncManager.shared.save(
            SyncableState(
                game: game,
                settings: settings,
                firstDealerIndex: firstDealerIndex,
                history: history
            )
        )
    }

    // MARK: - Game flow

    func newGame() {
        // Start a fresh game with the same players.
        game = HeartsGame(players: game.players)
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
        if isGameOver {
            archiveCompletedGameIfNeeded()
        } else {
            persistToCloud()
        }
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
            return winnerDescription(for: game) ?? "Game over"
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

    // MARK: - History helpers

    private func archiveCompletedGameIfNeeded() {
        guard isGameOver else { return }

        // Avoid duplicating this game in history.
        if history.contains(where: { $0.game.id == game.id }) {
            return
        }

        let completed = CompletedGame(game: game, settings: settings)
        history.insert(completed, at: 0)
        persistToCloud()
    }

    func deleteHistory(at offsets: IndexSet) {
        history.remove(atOffsets: offsets)
        persistToCloud()
    }

    func setAppearance(_ appearance: AppearancePreference) {
        settings.appearance = appearance
        UserDefaults.standard.set(appearance.rawValue, forKey: appearanceDefaultsKey)
    }

    func winnerDescription(for completed: CompletedGame) -> String {
        winnerDescription(for: completed.game) ?? "No winner"
    }

    private func winnerDescription(for game: HeartsGame) -> String? {
        let totals = game.totals()
        guard let minTotal = totals.map(\.total).min() else { return nil }
        let winners = totals.filter { $0.total == minTotal }.map(\.player.name)
        if winners.isEmpty {
            return nil
        } else if winners.count == 1, let name = winners.first {
            return "\(name) won!"
        } else {
            return "Game Over: " + winners.joined(separator: ", ")
        }
    }

    // MARK: - Private

    private func applyLocalAppearancePreference() {
        if let raw = UserDefaults.standard.string(forKey: appearanceDefaultsKey),
           let pref = AppearancePreference(rawValue: raw) {
            settings.appearance = pref
        }
    }
}

