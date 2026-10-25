import XCTest
@testable import HeartsScoreboard

final class PassDirectionTests: XCTestCase {
    func testEvenPlayerCountCyclesWithAcross() {
        let dirs = (0..<4).map { PassDirection.forPhase($0, playerCount: 4) }
        XCTAssertEqual(dirs, [.left, .right, .across, .hold])
        XCTAssertEqual((0..<4).map { PassDirection.forPhase($0, playerCount: 6) }, dirs)
    }

    func testOddPlayerCountSkipsAcross() {
        XCTAssertEqual((0..<3).map { PassDirection.forPhase($0, playerCount: 3) }, [.left, .right, .hold])
        XCTAssertEqual((0..<3).map { PassDirection.forPhase($0, playerCount: 5) }, [.left, .right, .hold])
    }

    func testSymbolsAreSFSymbolsNotGlyphs() {
        XCTAssertEqual(PassDirection.left.symbolName, "arrow.left")
        XCTAssertEqual(PassDirection.right.symbolName, "arrow.right")
        XCTAssertEqual(PassDirection.across.symbolName, "arrow.left.arrow.right")
        XCTAssertEqual(PassDirection.hold.symbolName, "hand.raised.fill")
    }

    @MainActor
    func testHeaderDirectionFollowsViewModelPhase() {
        let vm = GameViewModel(initialState: SyncableState(
            game: HeartsGame(players: ["A", "B", "C", "D"].map { .init(id: UUID(), name: $0) }, hands: []),
            settings: GameSettings(), firstDealerIndex: 0))
        let phase = vm.passDirectionPhaseIndex(forCompletedHandCount: 0)
        XCTAssertEqual(PassDirection.forPhase(phase, playerCount: 4), .left)
    }
}
