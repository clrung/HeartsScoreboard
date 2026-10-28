import XCTest
@testable import HeartsScoreboard

@MainActor
final class RedoAndEditTests: XCTestCase {
    private func makeModel(ending: Int = 100, tenRule: Bool = false) -> GameViewModel {
        let m = GameViewModel(initialState: SyncableState(game: HeartsGame(players: [
            .init(id: UUID(), name: "A"), .init(id: UUID(), name: "B"),
            .init(id: UUID(), name: "C"), .init(id: UUID(), name: "D")
        ]), settings: GameSettings(endingScore: ending, tenOfDiamondsMinus10: tenRule), firstDealerIndex: 1))
        m.persistsToCloud = false
        return m
    }

    private func ids(_ m: GameViewModel) -> [UUID] { m.game.players.map(\.id) }

    private func pts(_ m: GameViewModel, _ v: [Int]) -> [UUID: Int] {
        Dictionary(uniqueKeysWithValues: zip(ids(m), v))
    }

    // MARK: Undo / redo

    func testRedoRestoresExactHandAndDealer() {
        let m = makeModel(tenRule: true)
        let p = ids(m)
        m.addHand(pointsByPlayerID: pts(m, [13, 13, 0, 0]), tenOfDiamondsPlayerID: p[2])
        m.addHand(pointsByPlayerID: pts(m, [0, 20, 6, 0]), tenOfDiamondsPlayerID: p[3])
        let last = m.game.hands[1]
        let dealer = m.currentDealerIndex
        let totals = m.game.totals().map(\.total)
        XCTAssertFalse(m.canRedo)

        let removed = m.undoLastHand()
        XCTAssertEqual(removed, last)
        XCTAssertTrue(m.canRedo)
        XCTAssertEqual(m.game.hands.count, 1)

        let restored = m.redo()
        XCTAssertEqual(restored, last)
        XCTAssertEqual(m.game.hands.last, last, "same id, points, 10♦ holder and date")
        XCTAssertEqual(m.currentDealerIndex, dealer)
        XCTAssertEqual(m.game.totals().map(\.total), totals)
        XCTAssertFalse(m.canRedo)
        XCTAssertNil(m.redo())
    }

    func testQueenOwnerPersistsThroughAddEditUndoRedoAndSync() throws {
        let m = makeModel(tenRule: true)
        let p = ids(m)
        var entry = RoundEntryState()
        entry.points = pts(m, [13, 13, 0, 0])
        entry.queenOwnerID = p[1]
        entry.tenOfDiamondsOwnerID = p[2]
        XCTAssertTrue(entry.submit(to: m))
        let saved = try XCTUnwrap(m.game.hands.last)
        XCTAssertEqual(saved.queenOfSpadesPlayerID, p[1])
        XCTAssertEqual(saved.tenOfDiamondsPlayerID, p[2])

        // Encode to a file and load it back, covering the persisted Codable payload used for iCloud.
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("queen-hand-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: fileURL) }
        let payload = SyncableState(game: m.game, settings: m.settings, firstDealerIndex: m.firstDealerIndex)
        try JSONEncoder().encode(payload).write(to: fileURL)
        let restoredState = try JSONDecoder().decode(SyncableState.self, from: Data(contentsOf: fileURL))
        let restored = GameViewModel(initialState: restoredState)
        restored.persistsToCloud = false
        let restoredHand = try XCTUnwrap(restored.game.hands.last)
        XCTAssertEqual(restoredHand.queenOfSpadesPlayerID, p[1])
        XCTAssertEqual(restoredHand.tenOfDiamondsPlayerID, p[2])

        var editing = RoundEntryState(hand: restoredHand, players: restored.game.players)
        XCTAssertEqual(editing.queenOwnerID, p[1])
        XCTAssertEqual(editing.tenOfDiamondsOwnerID, p[2])
        editing.addQueenOfSpades(for: p[3])
        XCTAssertTrue(editing.save(over: restoredHand.id, in: restored))
        XCTAssertEqual(restored.game.hands.last?.queenOfSpadesPlayerID, p[3], "editing transfers the explicitly saved queen owner")
        XCTAssertEqual(restored.game.hands.last?.tenOfDiamondsPlayerID, p[2])

        XCTAssertEqual(restored.undoLastHand()?.queenOfSpadesPlayerID, p[3])
        XCTAssertEqual(restored.redo()?.queenOfSpadesPlayerID, p[3])
        let syncedData = try JSONEncoder().encode(SyncableState(game: restored.game, settings: restored.settings, firstDealerIndex: 0))
        let synced = try JSONDecoder().decode(SyncableState.self, from: syncedData)
        restored.applySyncedState(synced)
        XCTAssertEqual(restored.game.hands.last?.queenOfSpadesPlayerID, p[3])
        XCTAssertEqual(restored.game.hands.last?.tenOfDiamondsPlayerID, p[2])
    }

    func testLegacyHandWithoutQueenOwnerDecodesAsUnknown() throws {
        let id = UUID()
        let playerID = UUID()
        let legacyJSON = """
        {"id":"\(id.uuidString)","pointsByPlayerID":{"\(playerID.uuidString)":13},"notes":"","createdAt":0}
        """.data(using: .utf8)!
        let hand = try JSONDecoder().decode(HeartsGame.Hand.self, from: legacyJSON)
        XCTAssertNil(hand.queenOfSpadesPlayerID)
        let entry = RoundEntryState(hand: hand, players: [.init(id: playerID, name: "A")])
        XCTAssertNil(entry.queenOwnerID, "legacy score data cannot identify which 13 points came from Q♠")
    }

    func testUndoWithNothingReturnsNilAndRedoEmpty() {
        let m = makeModel()
        XCTAssertNil(m.undoLastHand())
        XCTAssertFalse(m.canRedo)
    }

    func testMultipleUndosRedoInReverseOrder() {
        let m = makeModel()
        m.addHand(pointsByPlayerID: pts(m, [13, 13, 0, 0]))
        m.addHand(pointsByPlayerID: pts(m, [0, 13, 13, 0]))
        let h = m.game.hands
        m.undoLastHand(); m.undoLastHand()
        XCTAssertEqual(m.redo(), h[0])
        XCTAssertEqual(m.redo(), h[1])
        XCTAssertEqual(m.game.hands, h)
    }

    func testNewRoundClearsRedo() {
        let m = makeModel()
        m.addHand(pointsByPlayerID: pts(m, [13, 13, 0, 0]))
        m.undoLastHand()
        XCTAssertTrue(m.canRedo)
        m.addHand(pointsByPlayerID: pts(m, [0, 13, 13, 0]))
        XCTAssertFalse(m.canRedo)
        XCTAssertNil(m.redo())
        XCTAssertEqual(m.game.hands.count, 1)
    }

    func testSyncClearsRedo() {
        let m = makeModel()
        m.addHand(pointsByPlayerID: pts(m, [13, 13, 0, 0]))
        m.undoLastHand()
        XCTAssertTrue(m.canRedo)
        m.applySyncedState(SyncableState(game: m.game, settings: m.settings, firstDealerIndex: 1))
        XCTAssertFalse(m.canRedo)
    }

    func testNewGameEditAndPlayerRemovalClearRedo() {
        let m = makeModel()
        m.addHand(pointsByPlayerID: pts(m, [13, 13, 0, 0]))
        m.addHand(pointsByPlayerID: pts(m, [0, 13, 13, 0]))
        m.undoLastHand()
        m.updateHand(id: m.game.hands[0].id, pointsByPlayerID: pts(m, [0, 0, 13, 13]))
        XCTAssertFalse(m.canRedo)

        m.undoLastHand()
        XCTAssertTrue(m.canRedo)
        m.newGame()
        XCTAssertFalse(m.canRedo)
    }

    func testUndoingTheFinalRoundUnArchivesAndRedoReArchives() {
        let m = makeModel(ending: 20)
        m.addHand(pointsByPlayerID: pts(m, [10, 16, 0, 0]))
        XCTAssertFalse(m.isGameOver)
        m.addHand(pointsByPlayerID: pts(m, [10, 16, 0, 0]))
        XCTAssertTrue(m.isGameOver)
        XCTAssertEqual(m.history.count, 1)

        m.undoLastHand()
        XCTAssertFalse(m.isGameOver)
        XCTAssertEqual(m.history.count, 0, "an unfinished game is not in history")

        m.redo()
        XCTAssertTrue(m.isGameOver)
        XCTAssertEqual(m.history.count, 1)
    }

    // MARK: updateHand

    func testUpdateHandKeepsIdentityAndRecomputesTotals() throws {
        let m = makeModel()
        let p = ids(m)
        m.addHand(pointsByPlayerID: pts(m, [13, 13, 0, 0]))
        m.addHand(pointsByPlayerID: pts(m, [0, 0, 26 - 5, 5]))
        let original = m.game.hands[0]

        XCTAssertTrue(m.updateHand(id: original.id, pointsByPlayerID: pts(m, [1, 2, 3, 20])))
        let edited = m.game.hands[0]
        XCTAssertEqual(edited.id, original.id)
        XCTAssertEqual(edited.createdAt, original.createdAt)
        XCTAssertEqual(edited.notes, original.notes)
        XCTAssertEqual(m.game.hands.count, 2)
        XCTAssertEqual(m.game.totalPoints(for: p[0]), 1)
        XCTAssertEqual(m.game.totalPoints(for: p[3]), 25)
        XCTAssertEqual(m.game.totalPoints(for: p[2]), 21 + 3)
    }

    func testUpdateHandRejectsInvalidAndUnknownAndChangesNothing() {
        let m = makeModel()
        m.addHand(pointsByPlayerID: pts(m, [13, 13, 0, 0]))
        let before = m.game
        let id = m.game.hands[0].id
        XCTAssertFalse(m.updateHand(id: id, pointsByPlayerID: pts(m, [26, 0, 0, 0])), "one player can't take all 26")
        XCTAssertFalse(m.updateHand(id: id, pointsByPlayerID: pts(m, [10, 10, 0, 0])), "sums to 20")
        XCTAssertFalse(m.updateHand(id: UUID(), pointsByPlayerID: pts(m, [13, 13, 0, 0])))
        XCTAssertFalse(m.updateHand(id: id, pointsByPlayerID: pts(m, [13, 13, 0, 0]), tenOfDiamondsPlayerID: UUID()))
        XCTAssertEqual(m.game, before)
    }

    func testUpdateHandRequiresHolderWhenTenRuleOn() {
        let m = makeModel(tenRule: true)
        let p = ids(m)
        m.addHand(pointsByPlayerID: pts(m, [13, 13, 0, 0]), tenOfDiamondsPlayerID: p[0])
        let id = m.game.hands[0].id
        XCTAssertFalse(m.updateHand(id: id, pointsByPlayerID: pts(m, [13, 13, 0, 0])))
        XCTAssertTrue(m.updateHand(id: id, pointsByPlayerID: pts(m, [13, 13, 0, 0]), tenOfDiamondsPlayerID: p[2]))
        XCTAssertEqual(m.game.hands[0].pointsByPlayerID[p[0]], 13)
        XCTAssertEqual(m.game.hands[0].pointsByPlayerID[p[2]], -10)
        XCTAssertEqual(m.game.hands[0].tenOfDiamondsPlayerID, p[2])
    }

    func testUpdateHandMoonWithTenOfDiamonds() {
        let m = makeModel(tenRule: true)
        let p = ids(m)
        // Shooter (A) also took the 10♦: final A = -10, others 26.
        m.addHand(pointsByPlayerID: pts(m, [0, 26, 26, 26]), tenOfDiamondsPlayerID: p[0])
        let id = m.game.hands[0].id
        XCTAssertTrue(m.game.isMoonHand(m.game.hands[0], for: p[0]))

        // Re-point the moon to B, 10♦ to C.
        XCTAssertTrue(m.updateHand(id: id, pointsByPlayerID: pts(m, [26, 0, 26, 26]), tenOfDiamondsPlayerID: p[2]))
        let h = m.game.hands[0]
        XCTAssertEqual(h.pointsByPlayerID[p[0]], 26)
        XCTAssertEqual(h.pointsByPlayerID[p[1]], 0)
        XCTAssertEqual(h.pointsByPlayerID[p[2]], 16)
        XCTAssertTrue(m.game.isMoonHand(h, for: p[1]))
        XCTAssertFalse(m.game.isMoonHand(h, for: p[0]))
    }

    func testUpdateHandSubtractMoon() {
        let m = makeModel()
        let p = ids(m)
        m.addHand(pointsByPlayerID: pts(m, [13, 13, 0, 0]))
        XCTAssertTrue(m.updateHand(id: m.game.hands[0].id, pointsByPlayerID: pts(m, [0, -26, 0, 0])))
        XCTAssertEqual(m.game.totalPoints(for: p[1]), -26)
        XCTAssertTrue(m.game.isMoonHand(m.game.hands[0], for: p[1]))
    }

    func testEditCanEndTheGameAndArchiveIt() {
        let m = makeModel(ending: 30)
        let p = ids(m)
        m.addHand(pointsByPlayerID: pts(m, [10, 16, 0, 0]))
        m.addHand(pointsByPlayerID: pts(m, [0, 13, 13, 0]))
        XCTAssertFalse(m.isGameOver)
        XCTAssertTrue(m.history.isEmpty)

        // B: 16 + 13 = 29; edit round 1 so B takes 20 -> 33.
        XCTAssertTrue(m.updateHand(id: m.game.hands[0].id, pointsByPlayerID: pts(m, [6, 20, 0, 0])))
        XCTAssertTrue(m.isGameOver)
        XCTAssertEqual(m.history.count, 1)
        XCTAssertEqual(m.history[0].game.id, m.game.id)
        XCTAssertEqual(m.history[0].game.totalPoints(for: p[1]), 33)
    }

    func testEditCanUnEndTheGameAndRemoveItsArchive() {
        let m = makeModel(ending: 30)
        m.addHand(pointsByPlayerID: pts(m, [10, 16, 0, 0]))
        m.addHand(pointsByPlayerID: pts(m, [0, 20, 6, 0]))
        XCTAssertTrue(m.isGameOver)
        XCTAssertEqual(m.history.count, 1)

        XCTAssertTrue(m.updateHand(id: m.game.hands[1].id, pointsByPlayerID: pts(m, [13, 0, 13, 0])))
        XCTAssertFalse(m.isGameOver)
        XCTAssertTrue(m.history.isEmpty, "game is no longer finished")
    }

    func testEditStillOverKeepsOneArchiveEntryWithNewScores() {
        let m = makeModel(ending: 30)
        let p = ids(m)
        m.addHand(pointsByPlayerID: pts(m, [0, 16, 10, 0]))
        m.addHand(pointsByPlayerID: pts(m, [0, 20, 6, 0]))
        let archived = m.history[0]

        XCTAssertTrue(m.updateHand(id: m.game.hands[1].id, pointsByPlayerID: pts(m, [0, 14, 12, 0])))
        XCTAssertTrue(m.isGameOver) // B: 16 + 14 = 30, exactly the ending score
        XCTAssertEqual(m.history.count, 1)
        XCTAssertEqual(m.history[0].id, archived.id)
        XCTAssertEqual(m.history[0].finishedAt, archived.finishedAt)
        XCTAssertEqual(m.history[0].game.totalPoints(for: p[2]), 22)
    }

    // MARK: RoundEntryState <-> Hand

    func testEntryFromHandRoundTripsThroughSave() {
        let m = makeModel(tenRule: true)
        let p = ids(m)
        m.addHand(pointsByPlayerID: pts(m, [20, 6, 0, 0]), tenOfDiamondsPlayerID: p[1])
        let hand = m.game.hands[0]
        XCTAssertEqual(hand.pointsByPlayerID[p[1]], -4)

        let entry = RoundEntryState(hand: hand, players: m.game.players)
        XCTAssertEqual(entry.points[p[0]], 20)
        XCTAssertEqual(entry.points[p[1]], 6, "the holder's -10 is backed out")
        XCTAssertEqual(entry.tenOfDiamondsOwnerID, p[1])
        XCTAssertTrue(entry.canSubmit(players: m.game.players, tenRuleOn: true))

        XCTAssertTrue(entry.save(over: hand.id, in: m))
        XCTAssertEqual(m.game.hands[0], hand, "saving an unchanged entry changes nothing")
    }

    func testEntryFromMoonHandRoundTrips() {
        let m = makeModel(tenRule: true)
        let p = ids(m)
        m.addHand(pointsByPlayerID: pts(m, [0, 26, 26, 26]), tenOfDiamondsPlayerID: p[0])
        let hand = m.game.hands[0]
        let entry = RoundEntryState(hand: hand, players: m.game.players)
        XCTAssertEqual(entry.points[p[0]], 0)
        XCTAssertTrue(entry.isRoundValid(players: m.game.players))
        XCTAssertTrue(entry.save(over: hand.id, in: m))
        XCTAssertEqual(m.game.hands[0], hand)
    }

    func testEntrySaveWithRuleOffKeepsExistingHolder() {
        let m = makeModel(tenRule: true)
        let p = ids(m)
        m.addHand(pointsByPlayerID: pts(m, [13, 13, 0, 0]), tenOfDiamondsPlayerID: p[2])
        let hand = m.game.hands[0]
        m.settings.tenOfDiamondsMinus10 = false

        var entry = RoundEntryState(hand: hand, players: m.game.players)
        entry.points[p[0]] = 12
        entry.points[p[3]] = 1
        XCTAssertTrue(entry.save(over: hand.id, in: m))
        XCTAssertEqual(m.game.hands[0].tenOfDiamondsPlayerID, p[2])
        XCTAssertEqual(m.game.hands[0].pointsByPlayerID[p[2]], -10)
    }

    func testEntrySaveRejectsInvalid() {
        let m = makeModel()
        let p = ids(m)
        m.addHand(pointsByPlayerID: pts(m, [13, 13, 0, 0]))
        let hand = m.game.hands[0]
        var entry = RoundEntryState(hand: hand, players: m.game.players)
        entry.points[p[0]] = 3
        XCTAssertFalse(entry.save(over: hand.id, in: m))
        XCTAssertEqual(m.game.hands[0], hand)
    }
}
