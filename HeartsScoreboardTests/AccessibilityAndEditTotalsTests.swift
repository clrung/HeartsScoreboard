import XCTest
@testable import HeartsScoreboard

@MainActor
final class AccessibilityAndEditTotalsTests: XCTestCase {
    private func makeModel() -> GameViewModel {
        let m = GameViewModel(initialState: SyncableState(game: HeartsGame(players: [
            .init(id: UUID(), name: "Ace"), .init(id: UUID(), name: "Deuce"),
            .init(id: UUID(), name: "Trey"), .init(id: UUID(), name: "Queen")
        ]), settings: GameSettings(), firstDealerIndex: 0))
        m.persistsToCloud = false
        return m
    }

    private func pts(_ m: GameViewModel, _ v: [Int]) -> [UUID: Int] {
        Dictionary(uniqueKeysWithValues: zip(m.game.players.map(\.id), v))
    }

    // MARK: Totals excluding an edited round

    func testTotalsExcludingHandLeaveOutOnlyThatHand() {
        let m = makeModel()
        m.addHand(pointsByPlayerID: pts(m, [13, 13, 0, 0]))
        m.addHand(pointsByPlayerID: pts(m, [0, 10, 16, 0]))
        m.addHand(pointsByPlayerID: pts(m, [5, 0, 0, 21]))
        let ids = m.game.players.map(\.id)
        let middle = m.game.hands[1].id

        XCTAssertEqual(m.game.totalPoints(for: ids[1]), 23)
        XCTAssertEqual(m.game.totalPoints(for: ids[1], excluding: middle), 13)
        XCTAssertEqual(m.game.totalPoints(for: ids[2], excluding: middle), 0)
        XCTAssertEqual(m.game.totals(excluding: middle).map(\.total), [18, 13, 0, 21])
    }

    func testExcludingNilOrUnknownHandChangesNothing() {
        let m = makeModel()
        m.addHand(pointsByPlayerID: pts(m, [13, 13, 0, 0]))
        let all = m.game.totals().map(\.total)
        XCTAssertEqual(m.game.totals(excluding: nil).map(\.total), all)
        XCTAssertEqual(m.game.totals(excluding: UUID()).map(\.total), all)
    }

    func testExcludingTheOnlyHandGivesZeros() {
        let m = makeModel()
        m.addHand(pointsByPlayerID: pts(m, [13, 13, 0, 0]))
        XCTAssertEqual(m.game.totals(excluding: m.game.hands[0].id).map(\.total), [0, 0, 0, 0])
    }

    // MARK: Announcements

    func testRoundAddedAnnouncementCarriesShakeHintOnlyWhenAsked() {
        let m = makeModel()
        m.addHand(pointsByPlayerID: pts(m, [13, 13, 0, 0]))
        XCTAssertEqual(m.roundAddedAnnouncement(includingShakeHint: false), m.roundAddedAnnouncement)
        let with = m.roundAddedAnnouncement(includingShakeHint: true)
        XCTAssertTrue(with.hasPrefix(m.roundAddedAnnouncement))
        XCTAssertTrue(with.hasSuffix(GameViewModel.shakeHintText))
    }

    func testUndoRedoAndEditAnnouncements() {
        XCTAssertEqual(GameViewModel.undoneMessage(round: 3), "Round 3 undone")
        XCTAssertEqual(GameViewModel.undoneAnnouncement(round: 3), "Round 3 undone. Redo available")
        XCTAssertEqual(GameViewModel.restoredAnnouncement(round: 3), "Round 3 restored")
        XCTAssertEqual(GameViewModel.updatedAnnouncement(round: 3), "Round 3 updated")
    }

    // MARK: Hold-to-repeat timing

    func testHoldRepeatWaitsThenRepeatsUntilCancelled() async {
        var count = 0
        let task = Task { @MainActor in
            await HoldRepeat.run(initialDelay: .milliseconds(150), interval: .milliseconds(20),
                                 fastInterval: .milliseconds(10), fastAfter: 3) { count += 1 }
        }
        try? await Task.sleep(for: .milliseconds(60))
        XCTAssertEqual(count, 0, "nothing fires before the initial delay (a plain tap must act once)")
        try? await Task.sleep(for: .milliseconds(400))
        task.cancel()
        await task.value
        let atCancel = count
        XCTAssertGreaterThan(atCancel, 3, "repeats while held")
        try? await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(count, atCancel, "stops as soon as the press ends")
    }

    func testHoldRepeatCancelledBeforeDelayNeverFires() async {
        var count = 0
        let task = Task { @MainActor in
            await HoldRepeat.run(initialDelay: .milliseconds(200)) { count += 1 }
        }
        try? await Task.sleep(for: .milliseconds(30))
        task.cancel()
        await task.value
        XCTAssertEqual(count, 0)
    }
}
