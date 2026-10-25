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

    func total(players: [HeartsGame.Player]) -> Int {
        players.reduce(0) { $0 + (points[$1.id] ?? 0) }
    }

    /// Valid Hearts round, judged on hearts/Q♠ points only (the 10♦ bonus is applied on submit).
    func isRoundValid(players: [HeartsGame.Player]) -> Bool {
        HeartsGame.isValidRound(penaltyScores: players.map { points[$0.id] ?? 0 })
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
