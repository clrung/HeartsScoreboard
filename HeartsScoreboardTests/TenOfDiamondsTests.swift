import XCTest
@testable import HeartsScoreboard

final class TenOfDiamondsTests: XCTestCase {
    private let a = HeartsGame.Player(id: UUID(), name: "A")
    private let b = HeartsGame.Player(id: UUID(), name: "B")
    private let c = HeartsGame.Player(id: UUID(), name: "C")
    private let d = HeartsGame.Player(id: UUID(), name: "D")

    private var game: HeartsGame { HeartsGame(players: [a, b, c, d]) }

    private func hand(_ points: [UUID: Int], ten: UUID?) -> HeartsGame.Hand {
        HeartsGame.Hand(
            id: UUID(),
            pointsByPlayerID: HeartsGame.finalPoints(penaltyPoints: points, tenOfDiamondsPlayerID: ten),
            notes: "",
            createdAt: Date(),
            tenOfDiamondsPlayerID: ten
        )
    }

    // MARK: Codable

    func testSettingsDecodesOldJSONWithoutNewKey() throws {
        let json = #"{"endingScore":80,"shootMoonPreference":"subtract26","appearance":"dark","quickIncrementPoints":4}"#
        let settings = try JSONDecoder().decode(GameSettings.self, from: Data(json.utf8))
        XCTAssertFalse(settings.tenOfDiamondsMinus10)
        XCTAssertEqual(settings.endingScore, 80)
    }

    func testSettingsRoundTripsNewKey() throws {
        var settings = GameSettings()
        settings.tenOfDiamondsMinus10 = true
        let decoded = try JSONDecoder().decode(GameSettings.self, from: JSONEncoder().encode(settings))
        XCTAssertTrue(decoded.tenOfDiamondsMinus10)
    }

    func testSyncedStateCarriesRule() throws {
        let state = SyncableState(game: game, settings: GameSettings(tenOfDiamondsMinus10: true), firstDealerIndex: 0)
        let decoded = try JSONDecoder().decode(SyncableState.self, from: JSONEncoder().encode(state))
        XCTAssertTrue(decoded.settings.tenOfDiamondsMinus10)
    }

    func testHandDecodesOldJSONWithoutHolder() throws {
        // UUID-keyed dictionaries encode as flat [key, value, ...] arrays.
        let json = """
        {"id":"\(UUID().uuidString)","pointsByPlayerID":["\(a.id.uuidString)",7],"notes":"","createdAt":0}
        """
        let hand = try JSONDecoder().decode(HeartsGame.Hand.self, from: Data(json.utf8))
        XCTAssertNil(hand.tenOfDiamondsPlayerID)
        XCTAssertEqual(hand.pointsByPlayerID[a.id], 7)
    }

    func testHandRoundTripsHolder() throws {
        let h = hand([a.id: 26, b.id: 0, c.id: 0, d.id: 0], ten: b.id)
        let decoded = try JSONDecoder().decode(HeartsGame.Hand.self, from: JSONEncoder().encode(h))
        XCTAssertEqual(decoded.tenOfDiamondsPlayerID, b.id)
        XCTAssertEqual(decoded, h)
    }

    // MARK: Totals

    func testTotalsIncludeMinusTen() {
        var g = game
        g.hands = [
            hand([a.id: 10, b.id: 16, c.id: 0, d.id: 0], ten: c.id),
            hand([a.id: 13, b.id: 13, c.id: 0, d.id: 0], ten: nil)
        ]
        XCTAssertEqual(g.totalPoints(for: a.id), 23)
        XCTAssertEqual(g.totalPoints(for: b.id), 29)
        XCTAssertEqual(g.totalPoints(for: c.id), -10)
        XCTAssertEqual(g.totalPoints(for: d.id), 0)
    }

    func testAddHandFoldsInMinusTen() {
        let model = GameViewModel(game: game)
        model.addHand(pointsByPlayerID: [a.id: 13, b.id: 13, c.id: 0, d.id: 0], tenOfDiamondsPlayerID: d.id)
        XCTAssertEqual(model.game.hands.last?.pointsByPlayerID[d.id], -10)
        XCTAssertEqual(model.game.hands.last?.tenOfDiamondsPlayerID, d.id)
    }

    // MARK: Moon detection

    func testAdd26MoonDetectedWhenShooterTookTen() {
        let h = hand([a.id: 0, b.id: 26, c.id: 26, d.id: 26], ten: a.id)
        XCTAssertTrue(game.isMoonHand(h, for: a.id))
        XCTAssertFalse(game.isMoonHand(h, for: b.id))
    }

    func testAdd26MoonDetectedWhenOtherTookTen() {
        let h = hand([a.id: 0, b.id: 26, c.id: 26, d.id: 26], ten: c.id)
        XCTAssertTrue(game.isMoonHand(h, for: a.id))
        XCTAssertFalse(game.isMoonHand(h, for: c.id))
    }

    func testSubtract26MoonDetectedWhenShooterTookTen() {
        let h = hand([a.id: -26, b.id: 0, c.id: 0, d.id: 0], ten: a.id)
        XCTAssertTrue(game.isMoonHand(h, for: a.id))
        XCTAssertFalse(game.isMoonHand(h, for: b.id))
    }

    func testSubtract26MoonDetectedWhenOtherTookTen() {
        let h = hand([a.id: -26, b.id: 0, c.id: 0, d.id: 0], ten: d.id)
        XCTAssertTrue(game.isMoonHand(h, for: a.id))
        XCTAssertFalse(game.isMoonHand(h, for: d.id))
    }

    func testNormalHandWithTenHolderIsNotMoon() {
        let h = hand([a.id: 10, b.id: 16, c.id: 0, d.id: 0], ten: c.id)
        for p in [a, b, c, d] {
            XCTAssertFalse(game.isMoonHand(h, for: p.id))
        }
    }

    // MARK: Round validity (penalty points only)

    func testRoundValidity() {
        XCTAssertTrue(HeartsGame.isValidRound(penaltyScores: [13, 13, 0, 0]))
        XCTAssertFalse(HeartsGame.isValidRound(penaltyScores: [26, 0, 0, 0]))
        XCTAssertTrue(HeartsGame.isValidRound(penaltyScores: [0, 26, 26, 26]))
        XCTAssertTrue(HeartsGame.isValidRound(penaltyScores: [-26, 0, 0, 0]))
        XCTAssertFalse(HeartsGame.isValidRound(penaltyScores: [10, 0, 0, 0]))
        XCTAssertFalse(HeartsGame.isValidRound(penaltyScores: []))
    }
}
