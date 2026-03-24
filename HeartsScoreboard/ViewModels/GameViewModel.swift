import Foundation
import Observation

enum ShootMoonPreference: String, CaseIterable, Identifiable, Codable {
    case add26
    case subtract26

    var id: String { rawValue }

    var label: String {
        switch self {
        case .add26: return String(localized: "Add 26")
        case .subtract26: return String(localized: "Subtract 26")
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
        case .system: return String(localized: "System")
        case .light: return String(localized: "Light")
        case .dark: return String(localized: "Dark")
        }
    }
}

struct GameSettings: Codable {
    var endingScore: Int = 100
    var shootMoonPreference: ShootMoonPreference = .add26
    var appearance: AppearancePreference = .system
    /// Points added by the round-input quick-add button (clamped 2–9).
    var quickIncrementPoints: Int = 5

    private enum CodingKeys: String, CodingKey {
        case endingScore
        case shootMoonPreference
        case appearance
        case quickIncrementPoints
    }

    init(
        endingScore: Int = 100,
        shootMoonPreference: ShootMoonPreference = .add26,
        appearance: AppearancePreference = .system,
        quickIncrementPoints: Int = 5
    ) {
        self.endingScore = endingScore
        self.shootMoonPreference = shootMoonPreference
        self.appearance = appearance
        self.quickIncrementPoints = Self.clampQuickIncrement(quickIncrementPoints)
    }

    static func clampQuickIncrement(_ value: Int) -> Int {
        min(9, max(2, value))
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        endingScore = try container.decodeIfPresent(Int.self, forKey: .endingScore) ?? 100
        shootMoonPreference = try container.decodeIfPresent(ShootMoonPreference.self, forKey: .shootMoonPreference) ?? .add26
        appearance = try container.decodeIfPresent(AppearancePreference.self, forKey: .appearance) ?? .system
        let quick = try container.decodeIfPresent(Int.self, forKey: .quickIncrementPoints) ?? 5
        quickIncrementPoints = Self.clampQuickIncrement(quick)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(endingScore, forKey: .endingScore)
        try container.encode(shootMoonPreference, forKey: .shootMoonPreference)
        try container.encode(appearance, forKey: .appearance)
        try container.encode(quickIncrementPoints, forKey: .quickIncrementPoints)
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

        // Remember who the current dealer is so we can keep the same person as dealer
        // after players are removed (if they still exist).
        let currentDealerID: UUID? = {
            guard game.players.indices.contains(firstDealerIndex) else { return nil }
            return game.players[firstDealerIndex].id
        }()

        let sorted = offsets.sorted()
        let indicesToRemove = Array(sorted.prefix(maxRemovable))
        game.players.remove(atOffsets: IndexSet(indicesToRemove))

        if let dealerID = currentDealerID,
           let newIndex = game.players.firstIndex(where: { $0.id == dealerID }) {
            // Keep the same player as dealer.
            firstDealerIndex = newIndex
        } else if firstDealerIndex >= game.players.count {
            // If the dealer was removed, fall back to the last valid player index.
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
            return winnerDescription(for: game) ?? String(localized: "Game over")
        }
        let phase = passDirectionPhaseIndex(forCompletedHandCount: game.hands.count)
        let oddPlayerCount = game.players.count % 2 == 1
        if oddPlayerCount {
            // 3 players (or 5): no "across" — cycle Left → Right → Hold.
            switch phase {
            case 0:
                return String(localized: "Pass to the Left")
            case 1:
                return String(localized: "Pass to the Right")
            default:
                return String(localized: "Hold on Tight!")
            }
        } else {
            // 4 or 6 players: full cycle including Across.
            switch phase {
            case 0:
                return String(localized: "Pass to the Left")
            case 1:
                return String(localized: "Pass to the Right")
            case 2:
                return String(localized: "Pass Across")
            default:
                return String(localized: "Hold on Tight!")
            }
        }
    }

    /// Phase index for the next pass direction after `forCompletedHandCount` hands.
    /// Odd player counts: 3 phases (Left, Right, Hold) — no Across.
    /// Even player counts: 4 phases (Left, Right, Across, Hold).
    func passDirectionPhaseIndex(forCompletedHandCount handCount: Int) -> Int {
        let n = game.players.count
        guard n > 0 else { return 0 }
        if n % 2 == 1 {
            return handCount % 3
        } else {
            return handCount % 4
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
        winnerDescription(for: completed.game) ?? String(localized: "No winner")
    }

    private func winnerDescription(for game: HeartsGame) -> String? {
        let totals = game.totals()
        guard let minTotal = totals.map(\.total).min() else { return nil }
        let winners = totals.filter { $0.total == minTotal }.map(\.player.name)
        if winners.isEmpty {
            return nil
        } else if winners.count == 1, let name = winners.first {
            return String(format: String(localized: "%@ won!"), name)
        } else {
            return String(format: String(localized: "%@ won!"), winners.joined(separator: ", "))
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

