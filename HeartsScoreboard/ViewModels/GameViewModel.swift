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
    /// Hands removed by `undoLastHand()` that `redo()` can put back, most recently undone last.
    /// Cleared by anything else that changes the game (new round, edit, new game, player changes, iCloud sync).
    private(set) var redoStack: [HeartsGame.Hand] = []

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
        redoStack.removeAll() // the synced game may no longer contain the hand we could redo onto
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
        redoStack.removeAll()
        persistToCloud()
    }

    /// - Parameter pointsByPlayerID: hearts/Q♠ points per player (without the 10♦ bonus).
    /// - Parameter tenOfDiamondsPlayerID: player who took the 10♦ when the rule is on; their -10 is folded into the stored points.
    func addHand(pointsByPlayerID: [UUID: Int], tenOfDiamondsPlayerID: UUID? = nil) {
        localRoundToken += 1
        redoStack.removeAll()
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
        reconcileArchivedGame()
        persistToCloud()
    }

    /// Replaces the points (and 10♦ holder) of an existing round, keeping its id, date and notes.
    /// Same rules as a new round: the hearts/Q♠ points must form a valid round, and with the 10♦ rule on a
    /// holder is required. Totals are derived, so they follow; the game may end or un-end as a result and
    /// the archived history entry is kept in step. Returns false (changing nothing) when rejected.
    /// - Parameter pointsByPlayerID: hearts/Q♠ points per player (without the 10♦ bonus), as for `addHand`.
    @discardableResult
    func updateHand(id: UUID, pointsByPlayerID: [UUID: Int], tenOfDiamondsPlayerID: UUID? = nil) -> Bool {
        guard let index = game.hands.firstIndex(where: { $0.id == id }) else { return false }
        let playerIDs = game.players.map(\.id)
        guard HeartsGame.isValidRound(penaltyScores: playerIDs.map { pointsByPlayerID[$0] ?? 0 }) else { return false }
        if let holder = tenOfDiamondsPlayerID, !playerIDs.contains(holder) { return false }
        if settings.tenOfDiamondsMinus10 && tenOfDiamondsPlayerID == nil { return false }

        var penalty: [UUID: Int] = [:]
        for pid in playerIDs { penalty[pid] = pointsByPlayerID[pid] ?? 0 }
        game.hands[index].pointsByPlayerID = HeartsGame.finalPoints(
            penaltyPoints: penalty,
            tenOfDiamondsPlayerID: tenOfDiamondsPlayerID
        )
        game.hands[index].tenOfDiamondsPlayerID = tenOfDiamondsPlayerID
        redoStack.removeAll()
        reconcileArchivedGame()
        persistToCloud()
        return true
    }

    func deleteHands(at offsets: IndexSet) {
        game.hands.remove(atOffsets: offsets)
        redoStack.removeAll()
        reconcileArchivedGame()
        persistToCloud()
    }

    /// Undo is available only when there is a round to remove.
    var canUndo: Bool { !game.hands.isEmpty }

    /// True when `redo()` has a just-undone round to put back.
    var canRedo: Bool { !redoStack.isEmpty }

    /// Removes the last round (no confirmation; the UI offers Redo instead) and remembers it for `redo()`.
    /// Dealer and pass direction are derived from the hand count, so they follow automatically.
    /// Returns the removed hand, or nil when there was nothing to undo.
    @discardableResult
    func undoLastHand() -> HeartsGame.Hand? {
        guard let hand = game.hands.popLast() else { return nil }
        redoStack.append(hand)
        reconcileArchivedGame()
        persistToCloud()
        return hand
    }

    /// Puts back the most recently undone round exactly as it was (same id, points, 10♦ holder, date).
    /// Returns the restored hand, or nil when there is nothing to redo.
    @discardableResult
    func redo() -> HeartsGame.Hand? {
        guard let hand = redoStack.popLast() else { return nil }
        game.hands.append(hand)
        reconcileArchivedGame()
        persistToCloud()
        return hand
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
        redoStack.removeAll() // a removed player's hand can't be put back cleanly

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
    var leadingPlayerIDs: Set<UUID> { leadingPlayerIDs(excluding: nil) }

    /// Leaders over every round except `handID` (the standing an edited round is being added to).
    /// Empty when no rounds remain after the exclusion, so nobody is crowned at 0-0.
    func leadingPlayerIDs(excluding handID: UUID?) -> Set<UUID> {
        guard game.hands.contains(where: { $0.id != handID }) else { return [] }
        let totals = game.totals(excluding: handID)
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

    /// The round-added announcement for the first round of a first-run game, with the shake-undo hint
    /// folded in so VoiceOver speaks one message instead of two competing ones.
    func roundAddedAnnouncement(includingShakeHint: Bool) -> String {
        guard includingShakeHint else { return roundAddedAnnouncement }
        return roundAddedAnnouncement + " " + Self.shakeHintText
    }

    static var shakeHintText: String { String(localized: "Shake to undo the last round!") }

    /// Spoken after an undo. `round` is the round that is now open again.
    static func undoneMessage(round: Int) -> String {
        String(format: String(localized: "Round %d undone"), round)
    }

    static func undoneAnnouncement(round: Int) -> String {
        undoneMessage(round: round) + ". " + String(localized: "Redo available")
    }

    static func restoredAnnouncement(round: Int) -> String {
        String(format: String(localized: "Round %d restored"), round)
    }

    static func updatedAnnouncement(round: Int) -> String {
        String(format: String(localized: "Round %d updated"), round)
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

    /// Keeps history in step with the current game: a finished game is archived once (an edit or redo
    /// refreshes its entry, keeping id and date), and a game that is no longer finished (undo, edit,
    /// delete) has its entry removed. Does not persist; callers do.
    private func reconcileArchivedGame() {
        let existing = history.firstIndex(where: { $0.game.id == game.id })
        if isGameOver {
            if let existing {
                let old = history[existing]
                history[existing] = CompletedGame(id: old.id, finishedAt: old.finishedAt, game: game, settings: settings)
            } else {
                history.insert(CompletedGame(game: game, settings: settings), at: 0)
            }
        } else if let existing {
            history.remove(at: existing)
        }
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
