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
    /// Optional Omnibus Hearts rule: whoever takes the 10♦ scores -10 for the hand.
    var tenOfDiamondsMinus10: Bool = false

    private enum CodingKeys: String, CodingKey {
        case endingScore
        case shootMoonPreference
        case appearance
        case quickIncrementPoints
        case tenOfDiamondsMinus10
    }

    init(
        endingScore: Int = 100,
        shootMoonPreference: ShootMoonPreference = .add26,
        appearance: AppearancePreference = .system,
        quickIncrementPoints: Int = 5,
        tenOfDiamondsMinus10: Bool = false
    ) {
        self.endingScore = endingScore
        self.shootMoonPreference = shootMoonPreference
        self.appearance = appearance
        self.quickIncrementPoints = Self.clampQuickIncrement(quickIncrementPoints)
        self.tenOfDiamondsMinus10 = tenOfDiamondsMinus10
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
        tenOfDiamondsMinus10 = try container.decodeIfPresent(Bool.self, forKey: .tenOfDiamondsMinus10) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(endingScore, forKey: .endingScore)
        try container.encode(shootMoonPreference, forKey: .shootMoonPreference)
        try container.encode(appearance, forKey: .appearance)
        try container.encode(quickIncrementPoints, forKey: .quickIncrementPoints)
        try container.encode(tenOfDiamondsMinus10, forKey: .tenOfDiamondsMinus10)
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
    /// When false, state is never pushed to iCloud (screenshot demo mode keeps its own isolated state).
    var persistsToCloud = true
    /// Bumped by every round added on THIS device (`addHand`). Views key the round-added haptic and
    /// VoiceOver announcement off this instead of `game.hands.count`, so a round that merely arrives
    /// via iCloud sync (which changes the count by one too) stays silent. Undo/sync never touch it.
    private(set) var localRoundToken = 0

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
        guard persistsToCloud else { return }
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

    /// Rematch after a finished game: same players, fresh scores. The finished game was already archived
    /// to history when its last round was added, so this is exactly the New Game path.
    func rematch() { newGame() }

    func newGame() {
        // Start a fresh game with the same players.
        game = HeartsGame(players: game.players)
        persistToCloud()
    }

    /// - Parameter pointsByPlayerID: hearts/Q♠ points per player (without the 10♦ bonus).
    /// - Parameter tenOfDiamondsPlayerID: player who took the 10♦ when the rule is on; their -10 is folded into the stored points.
    func addHand(pointsByPlayerID: [UUID: Int], tenOfDiamondsPlayerID: UUID? = nil) {
        localRoundToken += 1
        game.hands.append(
            .init(
                id: UUID(),
                pointsByPlayerID: HeartsGame.finalPoints(
                    penaltyPoints: pointsByPlayerID,
                    tenOfDiamondsPlayerID: tenOfDiamondsPlayerID
                ),
                notes: "",
                createdAt: Date(),
                tenOfDiamondsPlayerID: tenOfDiamondsPlayerID
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

    /// Undo is available only when there is a round to remove.
    var canUndo: Bool { !game.hands.isEmpty }

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

    /// Players with the lowest total (Hearts: lowest score leads). Empty before the first round
    /// so nobody is crowned while everyone is tied at zero.
    var leadingPlayerIDs: Set<UUID> {
        guard !game.hands.isEmpty else { return [] }
        let totals = game.totals()
        guard let minTotal = totals.map(\.total).min() else { return [] }
        return Set(totals.filter { $0.total == minTotal }.map(\.player.id))
    }

    /// Names of the current leaders, in seat order.
    var leadingPlayerNames: [String] {
        let ids = leadingPlayerIDs
        return game.players.filter { ids.contains($0.id) }.map(\.name)
    }

    /// Players with the highest total, i.e. closest to ending the game. Empty before any points are scored.
    var highestScorerIDs: Set<UUID> {
        let totals = game.totals()
        guard let maxTotal = totals.map(\.total).max(), maxTotal > 0 else { return [] }
        return Set(totals.filter { $0.total == maxTotal }.map(\.player.id))
    }

    /// Points a player can still take before reaching the ending score (never negative).
    func pointsRemaining(for playerID: UUID) -> Int {
        max(0, settings.endingScore - game.totalPoints(for: playerID))
    }

    /// Fraction of the ending score a player has reached, clamped to 0...1.
    func progress(for playerID: UUID) -> Double {
        guard settings.endingScore > 0 else { return 1 }
        let fraction = Double(game.totalPoints(for: playerID)) / Double(settings.endingScore)
        return min(1, max(0, fraction))
    }

    /// Points left before the game ends, shown only under the highest scorer(s) while the game is in play.
    func pointsToGo(for playerID: UUID) -> Int? {
        guard !isGameOver, highestScorerIDs.contains(playerID) else { return nil }
        return pointsRemaining(for: playerID)
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

    /// VoiceOver announcement for a round just added locally: the result when it ended the game,
    /// otherwise who leads.
    var roundAddedAnnouncement: String {
        if isGameOver { return gameOverAnnouncement }
        let leaders = ListFormatter.localizedString(byJoining: leadingPlayerNames)
        return String(format: String(localized: "Round added. %@ leads"), leaders)
    }

    // MARK: - Final standings

    /// Everyone ranked lowest total first (Hearts: lowest score wins). Ties share a rank and keep seat
    /// order; the next rank skips (1, 1, 3). Valid at any point, but meant for the game-over screen.
    var standings: [Standing] {
        let totals = game.totals()
        return totals
            .enumerated()
            .sorted { ($0.element.total, $0.offset) < ($1.element.total, $1.offset) }
            .map { entry in
                let rank = 1 + totals.filter { $0.total < entry.element.total }.count
                return Standing(rank: rank, player: entry.element.player, total: entry.element.total)
            }
    }

    /// The winners (everyone tied on the lowest total), in seat order.
    var winners: [Standing] { standings.filter(\.isWinner) }

    /// Spoken result: winner(s) and their score.
    var gameOverAnnouncement: String {
        let winners = winners
        guard let score = winners.first?.total else { return String(localized: "Game over") }
        let names = ListFormatter.localizedString(byJoining: winners.map(\.player.name))
        let key: String.LocalizationValue = winners.count == 1
            ? "\(names) won with \(score) points."
            : "\(names) tied for the win with \(score) points."
        return String(localized: key)
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


/// One row of the final standings.
struct Standing: Identifiable, Equatable {
    /// 1-based competition rank; tied players share it.
    let rank: Int
    let player: HeartsGame.Player
    let total: Int
    var id: UUID { player.id }
    var isWinner: Bool { rank == 1 }
}

extension HeartsGame {
    /// The 10♦ bonus (−10) to show next to the moon icon when this player shot the moon AND took the
    /// 10♦ that hand; nil otherwise. A moon cell has no number, so without this the −10 would be
    /// invisible. Display only: totals already include it.
    func moonCellTenOfDiamondsBonus(_ hand: Hand, for playerID: UUID) -> Int? {
        guard hand.tenOfDiamondsPlayerID == playerID, isMoonHand(hand, for: playerID) else { return nil }
        return Self.tenOfDiamondsPoints
    }
}
