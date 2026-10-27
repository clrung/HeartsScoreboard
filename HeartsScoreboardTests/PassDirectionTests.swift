import XCTest
import SwiftUI
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

final class DirectionalUITests: XCTestCase {
    func testBackAndNextSymbolsAreMirroringVariants() {
        XCTAssertEqual(DirectionalUI.backSymbol, "chevron.backward")
        XCTAssertEqual(DirectionalUI.nextRoundSymbol, "arrow.forward.circle.fill")
    }

    /// The leader crown must overhang the outer (trailing) side in both directions: the RTL render's
    /// left/right transparent margins are the LTR render's swapped.
    @MainActor
    func testCrownOverhangMirrorsInRTL() throws {
        func margins(_ dir: LayoutDirection) throws -> (left: Int, right: Int) {
            let view = PlayerTotalBadge(total: 50, isLeader: true, colorScheme: .light)
                .padding(.horizontal, 40)
                .frame(width: 200, height: 100)
                .environment(\.layoutDirection, dir)
            let r = ImageRenderer(content: view)
            r.scale = 1
            let cg = try XCTUnwrap(r.uiImage?.cgImage)
            let w = cg.width, h = cg.height
            var px = [UInt8](repeating: 0, count: w * h * 4)
            let ctx = try XCTUnwrap(CGContext(data: &px, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                              space: CGColorSpaceCreateDeviceRGB(),
                                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
            var minX = w, maxX = -1
            for y in 0..<h { for x in 0..<w where px[(y * w + x) * 4 + 3] > 20 { minX = min(minX, x); maxX = max(maxX, x) } }
            XCTAssertGreaterThan(maxX, minX)
            return (minX, w - 1 - maxX)
        }
        let ltr = try margins(.leftToRight), rtl = try margins(.rightToLeft)
        XCTAssertNotEqual(ltr.left, ltr.right, "crown should make the badge asymmetric")
        XCTAssertEqual(ltr.left, rtl.right, accuracy: 1)
        XCTAssertEqual(ltr.right, rtl.left, accuracy: 1)
    }

    func testChartIsAlwaysLeftToRight() {
        XCTAssertEqual(DirectionalUI.chartLayoutDirection, .leftToRight)
    }

    func testQuickAddTitleIsolatesNumberRun() {
        let t = DirectionalUI.quickAddTitle(points: 5)
        XCTAssertTrue(t.contains("\u{2066}+5\u{2069}"))
        XCTAssertEqual(t.replacingOccurrences(of: "\u{2066}", with: "").replacingOccurrences(of: "\u{2069}", with: ""),
                       String(format: String(localized: "Quick-add button: +%d"), 5))
    }
}
