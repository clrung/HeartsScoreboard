import XCTest
@testable import HeartsScoreboard

@MainActor
final class RoundEntryStateTests: XCTestCase {
    private let players = ["A", "B", "C", "D"].map { HeartsGame.Player(id: UUID(), name: $0) }

    private func model(tenRule: Bool = false) -> GameViewModel {
        GameViewModel(initialState: SyncableState(
            game: HeartsGame(players: players),
            settings: GameSettings(tenOfDiamondsMinus10: tenRule),
            firstDealerIndex: 0
        ))
    }

    private func validEntry() -> RoundEntryState {
        var e = RoundEntryState()
        e.reset(players: players)
        e.points[players[0].id] = 13
        e.points[players[1].id] = 13
        return e
    }

    func testResetClearsEntriesMoonAndTenOfDiamonds() {
        var e = validEntry()
        e.queenOwnerID = players[0].id
        e.tenOfDiamondsOwnerID = players[2].id
        e.points[players[1].id] = -26
        e.reset(players: players)
        XCTAssertEqual(e.points.count, players.count)
        XCTAssertTrue(e.points.values.allSatisfy { $0 == 0 })
        XCTAssertNil(e.queenOwnerID)
        XCTAssertNil(e.tenOfDiamondsOwnerID)
        XCTAssertFalse(e.isRoundValid(players: players))
    }

    func testSubmitBuildsHandAndResetAfterwardsClearsInlineEntry() {
        let m = model()
        var e = validEntry()
        XCTAssertTrue(e.submit(to: m))
        XCTAssertEqual(m.game.hands.count, 1)
        XCTAssertEqual(m.game.hands[0].pointsByPlayerID[players[0].id], 13)
        XCTAssertEqual(m.game.hands[0].pointsByPlayerID[players[1].id], 13)
        XCTAssertNil(m.game.hands[0].tenOfDiamondsPlayerID)
        e.reset(players: players)  // what the inline presentation does after submit
        XCTAssertEqual(e, { var f = RoundEntryState(); f.reset(players: players); return f }())
        XCTAssertFalse(e.submit(to: m))
        XCTAssertEqual(m.game.hands.count, 1)
    }

    func testSubmitAppliesTenOfDiamondsOnlyWhenRuleOn() {
        let m = model(tenRule: true)
        var e = validEntry()
        XCTAssertFalse(e.canSubmit(players: players, tenRuleOn: true), "holder required")
        XCTAssertFalse(e.submit(to: m))
        e.tenOfDiamondsOwnerID = players[2].id
        XCTAssertTrue(e.submit(to: m))
        XCTAssertEqual(m.game.hands[0].tenOfDiamondsPlayerID, players[2].id)
        XCTAssertEqual(m.game.hands[0].pointsByPlayerID[players[2].id], -10)

        // Rule off: a stale holder pick is ignored.
        let off = model()
        var stale = validEntry()
        stale.tenOfDiamondsOwnerID = players[2].id
        XCTAssertTrue(stale.submit(to: off))
        XCTAssertNil(off.game.hands[0].tenOfDiamondsPlayerID)
        XCTAssertEqual(off.game.hands[0].pointsByPlayerID[players[2].id], 0)
    }

    func testInvalidRoundCannotSubmit() {
        let m = model()
        var e = RoundEntryState()
        e.reset(players: players)
        XCTAssertFalse(e.submit(to: m))
        e.points[players[0].id] = 26  // one player taking all 26 is not valid
        XCTAssertFalse(e.canSubmit(players: players, tenRuleOn: false))
        XCTAssertFalse(e.submit(to: m))
        e.points[players[0].id] = 10
        e.points[players[1].id] = 10  // 20 / 26
        XCTAssertFalse(e.submit(to: m))
        XCTAssertTrue(m.game.hands.isEmpty)
    }

    func testShootTheMoonRoundsAreValid() {
        let m = model()
        var e = RoundEntryState()
        e.reset(players: players)
        for p in players { e.points[p.id] = p.id == players[0].id ? 0 : 26 }
        XCTAssertTrue(e.submit(to: m))
        e.reset(players: players)
        for p in players { e.points[p.id] = p.id == players[0].id ? -26 : 0 }
        XCTAssertTrue(e.submit(to: m))
        XCTAssertEqual(m.game.hands.count, 2)
    }

    func testQueenChipTransfersAndTogglesWithoutChangingHearts() {
        var e = RoundEntryState()
        e.reset(players: players)
        e.setPoints(for: players[0].id, to: 5)
        e.setPoints(for: players[1].id, to: 8)

        e.addQueenOfSpades(for: players[0].id)
        XCTAssertEqual(e.points[players[0].id], 18)
        XCTAssertEqual(e.queenOwnerID, players[0].id)

        e.addQueenOfSpades(for: players[1].id)
        XCTAssertEqual(e.points[players[0].id], 5, "transferring removes only the queen from the former owner")
        XCTAssertEqual(e.points[players[1].id], 21, "transferring adds the queen to the new owner's hearts")
        XCTAssertEqual(e.queenOwnerID, players[1].id)

        e.addQueenOfSpades(for: players[1].id)
        XCTAssertEqual(e.points[players[1].id], 8, "tapping the selected owner removes only the queen")
        XCTAssertNil(e.queenOwnerID)
    }

    func testQueenTransferPreservesPointsWhenItTakesTheEntryOver26() {
        let m = model()
        var e = RoundEntryState()
        e.reset(players: players)
        e.setPoints(for: players[0].id, to: 5)
        e.setPoints(for: players[1].id, to: 20)
        e.addQueenOfSpades(for: players[0].id)
        let totalBeforeTransfer = e.total(players: players)

        e.addQueenOfSpades(for: players[1].id)

        XCTAssertEqual(e.points[players[0].id], 5)
        XCTAssertEqual(e.points[players[1].id], 33)
        XCTAssertEqual(e.total(players: players), totalBeforeTransfer, "the transfer must not clamp away entered hearts")
        XCTAssertFalse(e.canSubmit(players: players, tenRuleOn: false))
        XCTAssertFalse(e.submit(to: m))
        XCTAssertTrue(m.game.hands.isEmpty)

        e.adjustPoints(for: players[1].id, delta: -1)
        XCTAssertEqual(e.points[players[1].id], 32, "a decrement corrects an overage by one step")
        e.addQueenOfSpades(for: players[1].id)
        XCTAssertEqual(e.points[players[1].id], 19, "toggling off the queen removes exactly 13")
        XCTAssertNil(e.queenOwnerID)
    }

    func testQueenTransferAndTenOfDiamondsSubmitUseAdjustedScores() {
        let m = model(tenRule: true)
        var e = RoundEntryState()
        e.reset(players: players)
        e.setPoints(for: players[0].id, to: 5)
        e.setPoints(for: players[1].id, to: 8)
        e.addQueenOfSpades(for: players[0].id)
        e.addQueenOfSpades(for: players[1].id)
        e.tenOfDiamondsOwnerID = players[0].id

        XCTAssertEqual(e.points[players[0].id], 5)
        XCTAssertEqual(e.points[players[1].id], 21)
        XCTAssertTrue(e.submit(to: m))
        XCTAssertEqual(m.game.hands[0].pointsByPlayerID[players[0].id], -5)
        XCTAssertEqual(m.game.hands[0].pointsByPlayerID[players[1].id], 21)
        XCTAssertEqual(m.game.hands[0].pointsByPlayerID.values.reduce(0, +), 16)
        XCTAssertEqual(m.game.hands[0].tenOfDiamondsPlayerID, players[0].id)
    }

    func testManualChangesKeepQueenOwnerAtOrAbove13() {
        var e = RoundEntryState()
        e.reset(players: players)
        e.addQueenOfSpades(for: players[0].id)

        XCTAssertEqual(e.minimumPoints(for: players[0].id), 13)
        XCTAssertEqual(e.minimumPoints(for: players[1].id), 0)
        e.setPoints(for: players[0].id, to: 0)
        XCTAssertEqual(e.points[players[0].id], 13)
        e.adjustPoints(for: players[0].id, delta: -30)
        XCTAssertEqual(e.points[players[0].id], 13)

        e.addQueenOfSpades(for: players[0].id)
        XCTAssertEqual(e.minimumPoints(for: players[0].id), 0)
        XCTAssertEqual(e.points[players[0].id], 0)
    }

    func testShootingTheMoonClearsQueenOwnership() {
        var e = RoundEntryState()
        e.reset(players: players)
        e.addQueenOfSpades(for: players[0].id)

        e.applyShootMoon(shooterID: players[2].id, players: players, preference: .add26)

        XCTAssertNil(e.queenOwnerID)
        XCTAssertEqual(e.points[players[2].id], 0)
        XCTAssertEqual(e.points[players[0].id], 26)
    }

    func testManualEntryClearsQueenOnlyForExactAdd26MoonPattern() {
        var e = RoundEntryState()
        e.reset(players: players)
        e.addQueenOfSpades(for: players[0].id)
        e.setPoints(for: players[0].id, to: 26)
        e.setPoints(for: players[1].id, to: 26)
        e.setPoints(for: players[3].id, to: 10)
        XCTAssertEqual(e.queenOwnerID, players[0].id)
        e.setPoints(for: players[2].id, to: 26)
        XCTAssertEqual(e.queenOwnerID, players[0].id, "the pattern is not a moon while one score is 10")
        e.adjustPoints(for: players[3].id, delta: -10)
        XCTAssertEqual(e.points, [players[0].id: 26, players[1].id: 26, players[2].id: 26, players[3].id: 0])
        XCTAssertNil(e.queenOwnerID, "the final manual adjustment completed the add-26 moon pattern")

        e.reset(players: players)
        e.addQueenOfSpades(for: players[0].id)
        e.setPoints(for: players[0].id, to: 26)
        e.setPoints(for: players[1].id, to: 26)
        e.setPoints(for: players[2].id, to: 13)
        e.setPoints(for: players[3].id, to: 13)
        XCTAssertEqual(e.total(players: players), 78)
        XCTAssertEqual(e.queenOwnerID, players[0].id, "a sum of 78 without the exact moon pattern keeps ownership")

        e.reset(players: players)
        e.addQueenOfSpades(for: players[0].id)
        e.setPoints(for: players[0].id, to: 13)
        e.setPoints(for: players[1].id, to: 13)
        XCTAssertEqual(e.total(players: players), 26)
        XCTAssertEqual(e.queenOwnerID, players[0].id, "a normal 26-point round is not a moon")
    }
}
