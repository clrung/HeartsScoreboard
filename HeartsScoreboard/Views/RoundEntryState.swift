import Foundation

/// The in-progress round entry behind `RoundInputView`: hearts/Q♠ points per player plus the Q♠ and 10♦ picks.
/// A plain value type so reset/submit logic can be unit tested without a view.
struct RoundEntryState: Equatable {
    var points: [UUID: Int] = [:]
    var queenOwnerID: UUID? = nil
    var tenOfDiamondsOwnerID: UUID? = nil

    init() {}

    /// Pre-fills the entry from an existing round, for editing. `Hand.pointsByPlayerID` holds final points,
    /// so the 10♦ holder's -10 is backed out to get the hearts/Q♠ points the entry works with. The Q♠ pick
    /// isn't recorded on a hand, so it stays unset.
    init(hand: HeartsGame.Hand, players: [HeartsGame.Player]) {
        var dict: [UUID: Int] = [:]
        for p in players {
            let final = hand.pointsByPlayerID[p.id] ?? 0
            dict[p.id] = p.id == hand.tenOfDiamondsPlayerID ? final - HeartsGame.tenOfDiamondsPoints : final
        }
        points = dict
        tenOfDiamondsOwnerID = hand.tenOfDiamondsPlayerID
    }

    /// Zeroes every player's points and clears the Q♠ and 10♦ picks.
    mutating func reset(players: [HeartsGame.Player]) {
        var dict: [UUID: Int] = [:]
        for p in players { dict[p.id] = 0 }
        points = dict
        queenOwnerID = nil
        tenOfDiamondsOwnerID = nil
    }

    /// Most points one player can take in a round (the whole deck's hearts + Q♠).
    static let maxPoints = 26

    /// The Q♠ is included in the selected player's total, so manual edits cannot take them below 13.
    func minimumPoints(for playerID: UUID) -> Int {
        queenOwnerID == playerID ? 13 : 0
    }

    /// Adds `delta`, clamped between that player's minimum and 26 unless an exact queen transfer
    /// temporarily put the entry above 26; then only negative steps reduce it.
    mutating func adjustPoints(for playerID: UUID, delta: Int) {
        guard delta != 0 else { return }
        let current = points[playerID] ?? 0
        if delta < 0 {
            points[playerID] = max(minimumPoints(for: playerID), current + delta)
        } else {
            let upperBound = max(current, Self.maxPoints)
            points[playerID] = max(minimumPoints(for: playerID), min(upperBound, current + delta))
        }
        clearQueenOwnerIfExactAdd26Moon()
    }

    /// Sets a player's points exactly, clamped between that player's current minimum and 26.
    mutating func setPoints(for playerID: UUID, to value: Int) {
        points[playerID] = max(minimumPoints(for: playerID), min(Self.maxPoints, value))
        clearQueenOwnerIfExactAdd26Moon()
    }

    /// Selects, transfers, or removes the Q♠ while keeping each player's heart points unchanged.
    /// The exact +13 can temporarily take an entry above 26 so no entered points are lost.
    mutating func addQueenOfSpades(for playerID: UUID) {
        if queenOwnerID == playerID {
            points[playerID] = max(0, (points[playerID] ?? 0) - 13)
            queenOwnerID = nil
            return
        }

        if let previousOwnerID = queenOwnerID {
            points[previousOwnerID] = max(0, (points[previousOwnerID] ?? 0) - 13)
        }

        // Keep the transfer exact even if the current entry is already over 26. The user can then
        // correct the other entered points without this action silently discarding any hearts.
        points[playerID] = (points[playerID] ?? 0) + 13
        queenOwnerID = playerID
        clearQueenOwnerIfExactAdd26Moon()
    }

    /// Q♠ ownership is incompatible with the add-26 moon distribution. Entry reset/edit paths
    /// populate a score for every player, so the full dictionary identifies that exact pattern.
    private mutating func clearQueenOwnerIfExactAdd26Moon() {
        let scores = Array(points.values)
        guard scores.count >= 3,
              scores.filter({ $0 == 0 }).count == 1,
              scores.allSatisfy({ $0 == 0 || $0 == Self.maxPoints }) else { return }
        queenOwnerID = nil
    }

    /// Rest chip: the points still missing from 26 (nothing when already at or over 26).
    mutating func addRemainingPoints(for playerID: UUID, players: [HeartsGame.Player]) {
        let delta = max(0, Self.maxPoints - total(players: players))
        guard delta > 0 else { return }
        adjustPoints(for: playerID, delta: delta)
    }

    /// Shoot the moon: add26 = shooter 0, everyone else 26. subtract26 = shooter -26, everyone else 0.
    mutating func applyShootMoon(shooterID: UUID, players: [HeartsGame.Player], preference: ShootMoonPreference) {
        queenOwnerID = nil
        for p in players {
            switch preference {
            case .add26: points[p.id] = p.id == shooterID ? 0 : 26
            case .subtract26: points[p.id] = p.id == shooterID ? -26 : 0
            }
        }
    }

    func total(players: [HeartsGame.Player]) -> Int {
        players.reduce(0) { $0 + (points[$1.id] ?? 0) }
    }

    /// Valid Hearts round, judged on hearts/Q♠ points only (the 10♦ bonus is applied on submit).
    func isRoundValid(players: [HeartsGame.Player]) -> Bool {
        HeartsGame.isValidRound(penaltyScores: players.map { points[$0.id] ?? 0 })
    }

    /// True when the round is valid and is a shoot-the-moon outcome (not a normal 26 split).
    func isShootTheMoon(players: [HeartsGame.Player]) -> Bool {
        let n = players.count
        guard n > 0, isRoundValid(players: players) else { return false }
        let sum = total(players: players)
        return sum == -26 || sum == (n - 1) * 26
    }

    /// The shooter of a moon round: the player at -26 (subtract preference) or the one at 0 while the
    /// others took 26 (add preference). nil when the entry isn't a moon round.
    func moonShooterID(players: [HeartsGame.Player]) -> UUID? {
        guard isShootTheMoon(players: players) else { return nil }
        if total(players: players) == -26 {
            return players.first { (points[$0.id] ?? 0) == -26 }?.id
        }
        return players.first { (points[$0.id] ?? 0) == 0 }?.id
    }

    /// Submit needs a valid 26-point round and, when the 10♦ rule is on, a chosen 10♦ holder.
    func canSubmit(players: [HeartsGame.Player], tenRuleOn: Bool) -> Bool {
        isRoundValid(players: players) && (!tenRuleOn || tenOfDiamondsOwnerID != nil)
    }

    /// Adds the entered round to `model`. Returns false (and changes nothing) when it can't be submitted.
    @discardableResult
    func submit(to model: GameViewModel) -> Bool {
        let tenRuleOn = model.settings.tenOfDiamondsMinus10
        guard canSubmit(players: model.game.players, tenRuleOn: tenRuleOn) else { return false }
        model.addHand(
            pointsByPlayerID: points,
            tenOfDiamondsPlayerID: tenRuleOn ? tenOfDiamondsOwnerID : nil
        )
        return true
    }
}

extension RoundEntryState {
    /// Saves this entry over the round `handID` (edit mode). Returns false (changing nothing) when rejected.
    /// The 10♦ holder is passed through as entered even when the rule is now off: the edit sheet has no
    /// picker then, and dropping the holder would silently change the round's points.
    @discardableResult
    func save(over handID: UUID, in model: GameViewModel) -> Bool {
        let tenRuleOn = model.settings.tenOfDiamondsMinus10
        guard canSubmit(players: model.game.players, tenRuleOn: tenRuleOn) else { return false }
        return model.updateHand(id: handID, pointsByPlayerID: points, tenOfDiamondsPlayerID: tenOfDiamondsOwnerID)
    }
}
