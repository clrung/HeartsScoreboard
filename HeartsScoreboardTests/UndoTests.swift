import XCTest
import UIKit
@testable import HeartsScoreboard

@MainActor
final class UndoTests: XCTestCase {
    private func makeModel() -> GameViewModel {
        GameViewModel(initialState: SyncableState(game: HeartsGame(players: [
            .init(id: UUID(), name: "A"), .init(id: UUID(), name: "B"),
            .init(id: UUID(), name: "C"), .init(id: UUID(), name: "D")
        ]), settings: GameSettings(), firstDealerIndex: 1))
    }

    func testUndoRemovesLastHandAndRestoresTotalsAndDealer() {
        let model = makeModel()
        let ids = model.game.players.map(\.id)
        XCTAssertFalse(model.canUndo)
        let dealer0 = model.currentDealerIndex

        model.addHand(pointsByPlayerID: [ids[0]: 26, ids[1]: 0, ids[2]: 0, ids[3]: 0])
        let totalsAfterOne = model.game.totals().map(\.total)
        let dealer1 = model.currentDealerIndex
        model.addHand(pointsByPlayerID: [ids[0]: 0, ids[1]: 13, ids[2]: 13, ids[3]: 0])
        XCTAssertTrue(model.canUndo)

        model.removeLastHand()
        XCTAssertEqual(model.game.hands.count, 1)
        XCTAssertEqual(model.game.totals().map(\.total), totalsAfterOne)
        XCTAssertEqual(model.currentDealerIndex, dealer1)

        model.removeLastHand()
        XCTAssertFalse(model.canUndo)
        XCTAssertEqual(model.currentDealerIndex, dealer0)
        model.removeLastHand() // no-op when empty
        XCTAssertTrue(model.game.hands.isEmpty)
    }

    /// Regression: after the first responder is lost (sheet dismissed), refocus() must restore it.
    func testShakeDetectorRegainsFirstResponderAfterLoss() {
        let window = UIWindow(frame: UIScreen.main.bounds)
        let vc = ShakeDetectorViewController(onShake: {})
        window.rootViewController = vc
        window.makeKeyAndVisible()
        vc.reclaimFirstResponder()
        XCTAssertTrue(vc.isFirstResponder)

        vc.resignFirstResponder() // what a presented sheet / viewWillDisappear does
        XCTAssertFalse(vc.isFirstResponder)

        vc.refocus()
        XCTAssertTrue(vc.isFirstResponder)
    }

    func testMotionShakeInvokesHandlerOnlyForShake() {
        var count = 0
        let vc = ShakeDetectorViewController(onShake: { count += 1 })
        vc.motionEnded(.none, with: nil)
        XCTAssertEqual(count, 0)
        vc.motionEnded(.motionShake, with: nil)
        XCTAssertEqual(count, 1)
    }
}
