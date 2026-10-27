import XCTest
@testable import HeartsScoreboard

@MainActor
final class RoundEntryKeyboardTests: XCTestCase {
    private let players = ["A", "B", "C", "D"].map { HeartsGame.Player(id: UUID(), name: $0) }
    private let t0 = Date(timeIntervalSinceReferenceDate: 1000)

    private func fresh() -> (RoundEntryState, RoundEntryKeyboard) {
        var e = RoundEntryState()
        e.reset(players: players)
        return (e, RoundEntryKeyboard())
    }

    private func press(_ c: RoundEntryKeyboard.Command, _ e: inout RoundEntryState, _ k: inout RoundEntryKeyboard,
                       pref: ShootMoonPreference = .add26, at: Date? = nil) {
        k.apply(c, to: &e, players: players, preference: pref, now: at ?? t0)
    }

    func testRingStaysHiddenUntilAKeyIsUsed() {
        let (_, k) = fresh()
        XCTAssertFalse(k.isActive)
        var (e, k2) = fresh()
        press(.move(1), &e, &k2)
        XCTAssertTrue(k2.isActive)
    }

    func testMoveWrapsBothWaysAndClearsBuffer() {
        var (e, k) = fresh()
        press(.move(-1), &e, &k)
        XCTAssertEqual(k.selectedIndex, 3)
        press(.move(1), &e, &k)
        XCTAssertEqual(k.selectedIndex, 0)
        press(.digit(1), &e, &k)
        press(.move(1), &e, &k)
        press(.digit(3), &e, &k, at: t0.addingTimeInterval(0.1))
        XCTAssertEqual(e.points[players[0].id], 1)
        XCTAssertEqual(e.points[players[1].id], 3, "row change starts a fresh number")
    }

    func testTwoDigitsWithinTheTimeoutMakeOneNumber() {
        var (e, k) = fresh()
        press(.digit(1), &e, &k)
        press(.digit(3), &e, &k, at: t0.addingTimeInterval(0.5))
        XCTAssertEqual(e.points[players[0].id], 13)
        // A third digit starts over.
        press(.digit(2), &e, &k, at: t0.addingTimeInterval(0.8))
        XCTAssertEqual(e.points[players[0].id], 2)
    }

    func testBufferExpiresAfterTheTimeout() {
        var (e, k) = fresh()
        press(.digit(1), &e, &k)
        press(.digit(3), &e, &k, at: t0.addingTimeInterval(RoundEntryKeyboard.digitTimeout + 0.2))
        XCTAssertEqual(e.points[players[0].id], 3)
    }

    func testTypedValuesAreClampedTo26() {
        var (e, k) = fresh()
        press(.digit(2), &e, &k)
        press(.digit(9), &e, &k, at: t0.addingTimeInterval(0.2))
        XCTAssertEqual(e.points[players[0].id], 26)
    }

    func testPlusMinusAndClear() {
        var (e, k) = fresh()
        press(.adjust(1), &e, &k)
        press(.adjust(1), &e, &k)
        press(.adjust(-1), &e, &k)
        XCTAssertEqual(e.points[players[0].id], 1)
        press(.adjust(-1), &e, &k)
        press(.adjust(-1), &e, &k)
        XCTAssertEqual(e.points[players[0].id], 0, "never below 0")
        press(.digit(7), &e, &k)
        press(.clear, &e, &k)
        XCTAssertEqual(e.points[players[0].id], 0)
    }

    func testQueenOnceThenRestAndSelectionFollowsRows() {
        var (e, k) = fresh()
        press(.queen, &e, &k)
        XCTAssertEqual(e.points[players[0].id], 13)
        XCTAssertEqual(e.queenOwnerID, players[0].id)
        press(.move(1), &e, &k)
        press(.queen, &e, &k)
        XCTAssertEqual(e.points[players[1].id], 0, "only one Q♠ per round")
        press(.rest, &e, &k)
        XCTAssertEqual(e.points[players[1].id], 13)
        XCTAssertTrue(e.isRoundValid(players: players))
        press(.adjust(1), &e, &k)
        XCTAssertEqual(e.points[players[1].id], 13, "+ is disabled once the round is valid, like the chip")
    }

    func testMoonFollowsPreferenceAndLocksTheValueKeys() {
        var (e, k) = fresh()
        press(.move(2), &e, &k)
        press(.moon, &e, &k, pref: .add26)
        XCTAssertEqual(e.moonShooterID(players: players), players[2].id)
        XCTAssertEqual(e.points[players[0].id], 26)
        press(.digit(5), &e, &k)
        press(.adjust(-1), &e, &k)
        press(.clear, &e, &k)
        XCTAssertEqual(e.points[players[2].id], 0)
        XCTAssertEqual(e.points[players[0].id], 26, "moon round ignores value keys, like the disabled controls")

        var (e2, k2) = fresh()
        press(.moon, &e2, &k2, pref: .subtract26)
        XCTAssertEqual(e2.points[players[0].id], -26)
        XCTAssertEqual(e2.moonShooterID(players: players), players[0].id)
    }

    func testSelectionClampsWhenPlayersShrink() {
        let k = RoundEntryKeyboard(selectedIndex: 9, isActive: true)
        XCTAssertEqual(k.selectedPlayerID(players: players), players[3].id)
        XCTAssertNil(k.selectedPlayerID(players: []))
    }

    // MARK: Lifted inline entry

    func testEntryResetKeyChangesForSubmitUndoNewGameAndSync_butNotForSettings() {
        let m = GameViewModel(initialState: SyncableState(game: HeartsGame(players: players), settings: GameSettings(), firstDealerIndex: 0))
        let k0 = m.entryResetKey
        m.settings.shootMoonPreference = .subtract26
        XCTAssertEqual(m.entryResetKey, k0, "changing a setting must not wipe a half-entered round")

        var pts: [UUID: Int] = [:]
        players.forEach { pts[$0.id] = 0 }
        pts[players[0].id] = 13; pts[players[1].id] = 13
        m.addHand(pointsByPlayerID: pts, tenOfDiamondsPlayerID: nil)
        let k1 = m.entryResetKey
        XCTAssertNotEqual(k1, k0)

        _ = m.undoLastHand()
        XCTAssertNotEqual(m.entryResetKey, k1)

        m.addHand(pointsByPlayerID: pts, tenOfDiamondsPlayerID: nil)
        let k2 = m.entryResetKey
        m.newGame()
        XCTAssertNotEqual(m.entryResetKey, k2)

        let synced = SyncableState(game: HeartsGame(players: ["W", "X", "Y"].map { HeartsGame.Player(id: UUID(), name: $0) }),
                                   settings: GameSettings(), firstDealerIndex: 0)
        let before = m.entryResetKey
        m.applySyncedState(synced)
        XCTAssertNotEqual(m.entryResetKey, before)
    }

    func testLiftedEntryResetsLikeTheInlinePanelDoes() {
        let m = GameViewModel(initialState: SyncableState(game: HeartsGame(players: players), settings: GameSettings(), firstDealerIndex: 0))
        var lifted = RoundEntryState()
        lifted.reset(players: players)
        var k = RoundEntryKeyboard()
        k.apply(.queen, to: &lifted, players: players, preference: .add26)
        XCTAssertEqual(lifted.queenOwnerID, players[0].id)
        XCTAssertTrue(lifted.points.values.contains(13))
        // What GameView does when the key changes: reset in place.
        lifted.reset(players: m.game.players)
        XCTAssertTrue(lifted.points.values.allSatisfy { $0 == 0 })
        XCTAssertNil(lifted.queenOwnerID)
    }

    func testKeyMap() {
        func cmd(_ c: String, _ sp: RoundEntryKeyboard.Special? = nil, shift: Bool = false, mod: Bool = false) -> RoundEntryKeyboard.Command? {
            RoundEntryKeyboard.command(characters: c, special: sp, shift: shift, hasShortcutModifier: mod)
        }
        XCTAssertEqual(cmd("7"), .digit(7))
        XCTAssertEqual(cmd("+"), .adjust(1))
        XCTAssertEqual(cmd("="), .adjust(1))
        XCTAssertEqual(cmd("-"), .adjust(-1))
        XCTAssertEqual(cmd("Q"), .queen)
        XCTAssertEqual(cmd("m"), .moon)
        XCTAssertEqual(cmd("r"), .rest)
        XCTAssertEqual(cmd("", .up), .move(-1))
        XCTAssertEqual(cmd("", .down), .move(1))
        XCTAssertEqual(cmd("", .tab), .move(1))
        XCTAssertEqual(cmd("", .tab, shift: true), .move(-1))
        XCTAssertEqual(cmd("", .delete), .clear)
        XCTAssertNil(cmd("z"))
        XCTAssertNil(cmd("q", mod: true), "⌘/⌃/⌥ combinations stay with the app shortcuts")
        XCTAssertNil(cmd("z", mod: true))
    }
}
