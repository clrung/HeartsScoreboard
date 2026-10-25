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
}
