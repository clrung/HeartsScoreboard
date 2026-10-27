import XCTest
import SwiftUI
import UIKit
@testable import HeartsScoreboard

/// Renders GameView at iPhone Duo display sizes (the simulator can't be unfolded from the CLI)
/// and writes PNGs to $SNAPSHOT_DIR (pass `TEST_RUNNER_SNAPSHOT_DIR=...` to xcodebuild) or the temp dir.
/// Models are built from in-memory state only and never mutated, so nothing is persisted to iCloud/UserDefaults.
@MainActor
final class DuoLayoutSnapshotTests: XCTestCase {
    private static let innerPortrait = CGSize(width: 669, height: 951)
    private static let innerLandscape = CGSize(width: 951, height: 669)
    private static let outer = CGSize(width: 466, height: 678)

    // MARK: Fixtures

    private func players(_ names: [String]) -> [HeartsGame.Player] {
        names.map { .init(id: UUID(), name: $0) }
    }

    /// Deterministic valid rounds: round r gives the 26 points to a rotating pair/split.
    private func hands(for players: [HeartsGame.Player], rounds: Int, tenRule: Bool = false) -> [HeartsGame.Hand] {
        (0..<rounds).map { r in
            var pts: [UUID: Int] = [:]
            players.forEach { pts[$0.id] = 0 }
            let a = players[r % players.count].id
            let b = players[(r + 1) % players.count].id
            pts[a] = 13 + (r % 3)
            pts[b] = 13 - (r % 3)
            if r == 3 { // one shoot-the-moon hand
                players.forEach { pts[$0.id] = 26 }
                pts[a] = 0
            }
            // On the moon hand the shooter also took the 10♦ (shows the "−10" beside the moon).
            let holder = tenRule ? (r == 3 ? a : players[(r + 2) % players.count].id) : nil
            if let holder { pts[holder, default: 0] -= 10 }
            return .init(id: UUID(), pointsByPlayerID: pts, notes: "", createdAt: Date(), tenOfDiamondsPlayerID: holder)
        }
    }

    private func model(names: [String], rounds: Int, tenRule: Bool = false, gameOver: Bool = false) -> GameViewModel {
        let ps = players(names)
        var hs = hands(for: ps, rounds: rounds, tenRule: tenRule)
        if gameOver {
            var pts: [UUID: Int] = [:]
            ps.forEach { pts[$0.id] = 0 }
            pts[ps[0].id] = 26
            pts[ps[1].id] = 26 // sum is not required to be valid for display
            hs.append(.init(id: UUID(), pointsByPlayerID: pts, notes: "", createdAt: Date()))
            for _ in 0..<4 { hs.append(hs[hs.count - 1]) }
        }
        let game = HeartsGame(players: ps, hands: hs)
        return GameViewModel(initialState: SyncableState(
            game: game,
            settings: GameSettings(tenOfDiamondsMinus10: tenRule),
            firstDealerIndex: 0
        ))
    }

    // MARK: Harness

    private struct Rendered {
        let image: UIImage
        let window: UIWindow
    }

    private func render(_ name: String, size: CGSize, regular: Bool, model: GameViewModel,
                        dark: Bool = false, category: UIContentSizeCategory? = nil,
                        root: AnyView? = nil, cancelSideInsets: Bool = false,
                        highContrast: Bool = false) throws -> Rendered {
        // A window without a scene doesn't render; attach to the host app's scene.
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(origin: .zero, size: size)
        window.traitOverrides.horizontalSizeClass = regular ? .regular : .compact
        window.traitOverrides.verticalSizeClass = regular ? .regular : .compact
        if size.width > size.height && !regular { window.traitOverrides.verticalSizeClass = .compact }
        window.overrideUserInterfaceStyle = dark ? .dark : .light
        if let category { window.traitOverrides.preferredContentSizeCategory = category }
        if highContrast { window.traitOverrides.accessibilityContrast = .high }
        let host = UIHostingController(rootView: root ?? AnyView(GameView(model: model)))
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.frame = window.bounds
        host.view.layoutIfNeeded()
        // The host scene's safe area (an outer-display/landscape scene) leaks into our window; replace it
        // with a plausible unfolded-display one (home indicator only).
        let leaked = host.view.safeAreaInsets
        let want = UIEdgeInsets(top: 0, left: 0, bottom: 21, right: 0)
        host.additionalSafeAreaInsets = UIEdgeInsets(
            top: want.top - leaked.top + host.additionalSafeAreaInsets.top,
            left: want.left - leaked.left + host.additionalSafeAreaInsets.left,
            bottom: want.bottom - leaked.bottom + host.additionalSafeAreaInsets.bottom,
            right: want.right - leaked.right + host.additionalSafeAreaInsets.right)
        // The scene's side insets also reach UIKit-backed scroll views through the window; cancel them.
        if cancelSideInsets {
            host.additionalSafeAreaInsets.left -= window.safeAreaInsets.left
            host.additionalSafeAreaInsets.right -= window.safeAreaInsets.right
        }
        host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.5))
        host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))

        print("SNAPDBG  \(name) window=\(window.frame) host=\(host.view.frame) safe=\(host.view.safeAreaInsets) tc=\(host.traitCollection.horizontalSizeClass.rawValue) scale=\(host.traitCollection.displayScale)")
        let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
        let image = renderer.image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        XCTAssertGreaterThan(image.size.width, 0)
        let data = try XCTUnwrap(image.pngData())
        XCTAssertGreaterThan(data.count, 1000)

        let dir = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"] ?? NSTemporaryDirectory()
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        try data.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
        return Rendered(image: image, window: window)
    }

    /// RGB (0...1) of the pixel at a point (in points) of the rendered image.
    private func pixel(_ image: UIImage, _ x: CGFloat, _ y: CGFloat) -> (r: CGFloat, g: CGFloat, b: CGFloat) {
        let scale = image.scale
        guard let cg = image.cgImage?.cropping(to: CGRect(x: x * scale, y: y * scale, width: 1, height: 1)) else { return (0, 0, 0) }
        var px = [UInt8](repeating: 0, count: 4)
        let ctx = CGContext(data: &px, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                            space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        return (CGFloat(px[0]) / 255, CGFloat(px[1]) / 255, CGFloat(px[2]) / 255)
    }

    /// The inline panel is a light, near-white (Theme.cardSurface) card on the green table.
    private func isPanelColor(_ c: (r: CGFloat, g: CGFloat, b: CGFloat), dark: Bool = false) -> Bool {
        // Theme.cardSurface dark is (0.11, 0.15, 0.13); the felt is darker in red (< 0.07).
        if dark { return c.r > 0.09 && c.r < 0.14 && c.g < 0.18 && c.b < 0.16 }
        return min(c.r, c.g, c.b) > 0.9 && max(c.r, c.g, c.b) - min(c.r, c.g, c.b) < 0.04
    }

    /// Regular layout: inline round-entry panel on the right (just right of the center gap), and
    /// nothing but table background across the vertical center line.
    private func assertSplit(_ r: Rendered, dark: Bool = false, line: UInt = #line) {
        let size = r.image.size
        let panel = pixel(r.image, size.width / 2 + 28, 125) // "Round N" title row, in the right card's left padding (the moon menu sits further right)
        XCTAssertTrue(isPanelColor(panel, dark: dark), "inline panel expected in right pane, got \(panel)", line: line)
        for y in stride(from: CGFloat(160), to: size.height - 60, by: 40) {
            let c = pixel(r.image, size.width / 2, y)
            XCTAssertFalse(isPanelColor(c, dark: dark), "control/panel crosses center line at y=\(y): \(c)", line: line)
        }
    }

    // MARK: Tests

    func testInlineSplitRequiresRegularWidthAndHeight() {
        XCTAssertTrue(GameView.usesSplitLayout(horizontal: .regular, vertical: .regular, idiom: .phone),
                      "unfolded Duo retains inline round entry")
        XCTAssertFalse(GameView.usesSplitLayout(horizontal: .regular, vertical: .compact, idiom: .phone),
                       "landscape phone uses the full-width scoreboard and round sheet")
        XCTAssertTrue(GameView.usesSplitLayout(horizontal: .regular, vertical: .compact, idiom: .pad),
                      "iPad keeps its split layout in landscape")
        XCTAssertFalse(GameView.usesSplitLayout(horizontal: .compact, vertical: .regular, idiom: .phone))
        XCTAssertFalse(GameView.usesSplitLayout(horizontal: .compact, vertical: .regular, idiom: .pad))
        XCTAssertFalse(GameView.usesSplitLayout(horizontal: .compact, vertical: .compact, idiom: .phone))
    }

    func testInner4Players5RoundsPortrait() throws {
        let r = try render("inner-4p-5r-portrait", size: Self.innerPortrait, regular: true,
                           model: model(names: ["Ace", "Deuce", "Trey", "Queen"], rounds: 5))
        assertSplit(r)
    }

    func testInner4Players5RoundsLandscape() throws {
        let r = try render("inner-4p-5r-landscape", size: Self.innerLandscape, regular: true,
                           model: model(names: ["Ace", "Deuce", "Trey", "Queen"], rounds: 5))
        assertSplit(r)
    }

    func testInner6PlayersLongNames8RoundsPortrait() throws {
        let names = ["Alexandra", "Bartholomew", "Christopher", "Dominique", "Evangeline", "Fitzgerald"]
        let r = try render("inner-6p-8r-portrait", size: Self.innerPortrait, regular: true,
                           model: model(names: names, rounds: 8))
        assertSplit(r)
    }

    func testInner6PlayersLongNames8RoundsLandscape() throws {
        let names = ["Alexandra", "Bartholomew", "Christopher", "Dominique", "Evangeline", "Fitzgerald"]
        let r = try render("inner-6p-8r-landscape", size: Self.innerLandscape, regular: true,
                           model: model(names: names, rounds: 8))
        assertSplit(r)
    }

    func testInnerGameOverPortrait() throws {
        let m = model(names: ["Ace", "Deuce", "Trey", "Queen"], rounds: 3, gameOver: true)
        XCTAssertTrue(m.isGameOver)
        // The right pane now holds the game-over card (also a light card), so this is a visual-review PNG.
        _ = try render("inner-gameover-portrait", size: Self.innerPortrait, regular: true, model: m)
    }

    // MARK: Game over (visual review)

    func testInnerGameOverLandscape() throws {
        let m = model(names: ["Ace", "Deuce", "Trey", "Queen"], rounds: 3, gameOver: true)
        _ = try render("inner-gameover-landscape", size: Self.innerLandscape, regular: true, model: m)
    }

    func testInnerGameOverSixPlayersDark() throws {
        let names = ["Alexandra", "Bartholomew", "Christopher", "Dominique", "Evangeline", "Fitzgerald"]
        let m = model(names: names, rounds: 3, gameOver: true)
        _ = try render("inner-gameover-6p-dark", size: Self.innerPortrait, regular: true, model: m, dark: true)
    }

    func testOuterGameOverCard() throws {
        let m = model(names: ["Ace", "Deuce", "Trey", "Queen"], rounds: 3, gameOver: true)
        _ = try render("outer-gameover", size: Self.outer, regular: false, model: m)
    }

    func testOuterGameOverCardAccessibilityTextSize() throws {
        let names = ["Alexandra", "Bartholomew", "Christopher", "Dominique", "Evangeline", "Fitzgerald"]
        let m = model(names: names, rounds: 3, gameOver: true)
        _ = try render("outer-gameover-6p-ax3", size: Self.outer, regular: false, model: m,
                       category: .accessibilityExtraLarge)
    }

    func testOuterGameOverConfettiFrame() throws {
        // Confetti started 1.2s ago: a mid-fall frame over the card.
        let m = model(names: ["Ace", "Deuce", "Trey", "Queen"], rounds: 3, gameOver: true)
        let root = AnyView(ZStack {
            GameOverView(standings: m.standings, onRematch: {}, onViewHistory: {}, onClose: {}).padding(20)
            ConfettiView(start: Date().addingTimeInterval(-1.2))
        }.background(Color.green))
        _ = try render("outer-gameover-confetti", size: Self.outer, regular: false, model: m, root: root)
    }

    func testInnerTenOfDiamondsPortrait() throws {
        let r = try render("inner-4p-10d-portrait", size: Self.innerPortrait, regular: true,
                           model: model(names: ["Ace", "Deuce", "Trey", "Queen"], rounds: 5, tenRule: true))
        assertSplit(r)
    }

    func testInnerTenOfDiamonds6PlayersPortrait() throws {
        let names = ["Alexandra", "Bartholomew", "Christopher", "Dominique", "Evangeline", "Fitzgerald"]
        let r = try render("inner-6p-10d-portrait", size: Self.innerPortrait, regular: true,
                           model: model(names: names, rounds: 8, tenRule: true))
        assertSplit(r)
    }

    func testInner4PlayersDarkPortrait() throws {
        let r = try render("inner-4p-5r-portrait-dark", size: Self.innerPortrait, regular: true,
                           model: model(names: ["Ace", "Deuce", "Trey", "Queen"], rounds: 5), dark: true)
        assertSplit(r, dark: true)
    }

    func testOuterCompactControl() throws {
        let r = try render("outer-compact-4p-5r", size: Self.outer, regular: false,
                           model: model(names: ["Ace", "Deuce", "Trey", "Queen"], rounds: 5))
        XCTAssertFalse(isPanelColor(pixel(r.image, 466 * 0.75, 125)), "compact layout has no inline panel")
    }

    // MARK: Dynamic Type (visual review only: PNGs, plus a "renders something" check)

    func testOuterAccessibilityTextSize4Players() throws {
        _ = try render("outer-compact-4p-10d-ax3", size: Self.outer, regular: false,
                       model: model(names: ["Ace", "Deuce", "Trey", "Queen"], rounds: 6, tenRule: true),
                       category: .accessibilityExtraLarge)
    }

    func testOuterAccessibilityTextSize6Players() throws {
        let names = ["Alexandra", "Bartholomew", "Christopher", "Dominique", "Evangeline", "Fitzgerald"]
        _ = try render("outer-compact-6p-10d-ax3", size: Self.outer, regular: false,
                       model: model(names: names, rounds: 6, tenRule: true),
                       category: .accessibilityExtraLarge)
    }

    func testInner6PlayersAccessibilityTextSizeSplit() throws {
        let names = ["Alexandra", "Bartholomew", "Christopher", "Dominique", "Evangeline", "Fitzgerald"]
        _ = try render("inner-6p-10d-portrait-ax3", size: Self.innerPortrait, regular: true,
                       model: model(names: names, rounds: 6, tenRule: true),
                       category: .accessibilityExtraLarge)
    }

    func testOuterLargeTextSize6Players() throws {
        let names = ["Alexandra", "Bartholomew", "Christopher", "Dominique", "Evangeline", "Fitzgerald"]
        _ = try render("outer-compact-6p-10d-xxxl", size: Self.outer, regular: false,
                       model: model(names: names, rounds: 6, tenRule: true),
                       category: .extraExtraExtraLarge)
    }

    // MARK: Main-screen polish (chips, pass-direction pill, bottom-bar heights)

    // The pass-direction pill never truncates by construction (ViewThatFits: word, else arrow only);
    // that is checked visually in the polish-*.png snapshots.
    private static let iPhoneAir = CGSize(width: 420, height: 912)
    private static let iPad11 = CGSize(width: 834, height: 1210)

    /// Vertical extent (top, bottom, in points) of the non-felt content at
    /// column `x`: compares each pixel with the felt at the screen's left edge on the same row. (Accessibility
    /// frames aren't available in a unit-test host, so this measures the rendered pixels.)
    private func extent(_ image: UIImage, x: CGFloat) -> (top: CGFloat, bottom: CGFloat)? {
        func differs(_ y: CGFloat) -> Bool {
            let p = pixel(image, x, y), f = pixel(image, 2, y)
            return abs(p.r - f.r) + abs(p.g - f.g) + abs(p.b - f.b) > 0.12
        }
        // Walk up from the home-indicator inset to the first button pixel, then up to its top edge (the
        // scoreboard card above is separated from the bar by a felt gap, so the block stays contiguous).
        var y = image.size.height - 22
        while y > image.size.height * 0.6 && !differs(y) { y -= 0.5 }
        guard y > image.size.height * 0.6 else { return nil }
        let bottom = y
        while y > image.size.height * 0.6 && differs(y) { y -= 0.5 }
        return (y, bottom)
    }

    private func luminance(_ c: (r: CGFloat, g: CGFloat, b: CGFloat)) -> CGFloat { 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b }

    private func polish(_ name: String, size: CGSize, regular: Bool, dark: Bool, category: UIContentSizeCategory?) throws {
        let r = try render("polish-\(name)", size: size, regular: regular,
                           model: model(names: ["Ace", "Deuce", "Trey", "Queen"], rounds: 5),
                           dark: dark, category: category)
        let w = size.width
        // The iPad split layout has no Next Round button, so only the phone layout compares heights.
        if !regular {
            let next = try XCTUnwrap(extent(r.image, x: w * 0.7), "Next Round not found (\(name))")
            let newGame = try XCTUnwrap(extent(r.image, x: w * 0.095), "New Game chip not found (\(name))")
            XCTAssertEqual(newGame.top, next.top, accuracy: 1.5, "New Game chip top must match Next Round (\(name))")
            XCTAssertEqual(newGame.bottom, next.bottom, accuracy: 1.5, "New Game chip bottom must match Next Round (\(name))")
            if dark {
                // Just inside the chip's top edge (above its icon): the lifted felt fill, not the old near-black one.
                let chip = pixel(r.image, w * 0.095, newGame.top + 6)
                XCTAssertGreaterThan(luminance(chip), 0.3, "dark-mode chip too dark against the felt (\(name))")
            }
        }
    }

    func testPolishAirDefaultLight() throws { try polish("air-default-light", size: Self.iPhoneAir, regular: false, dark: false, category: nil) }
    func testPolishAirDefaultDark() throws { try polish("air-default-dark", size: Self.iPhoneAir, regular: false, dark: true, category: nil) }
    func testPolishAirXXXLLight() throws { try polish("air-xxxl-light", size: Self.iPhoneAir, regular: false, dark: false, category: .extraExtraExtraLarge) }
    func testPolishAirXXXLDark() throws { try polish("air-xxxl-dark", size: Self.iPhoneAir, regular: false, dark: true, category: .extraExtraExtraLarge) }
    func testPolishIPadDefaultLight() throws { try polish("ipad-default-light", size: Self.iPad11, regular: true, dark: false, category: nil) }
    func testPolishIPadDefaultDark() throws { try polish("ipad-default-dark", size: Self.iPad11, regular: true, dark: true, category: nil) }
    func testPolishIPadXXXLLight() throws { try polish("ipad-xxxl-light", size: Self.iPad11, regular: true, dark: false, category: .extraExtraExtraLarge) }
    func testPolishIPadXXXLDark() throws { try polish("ipad-xxxl-dark", size: Self.iPad11, regular: true, dark: true, category: .extraExtraExtraLarge) }

    func testInner6PlayersTenRuleMoonDefaultSize() throws {
        _ = try render("outer-compact-6p-10d-default", size: Self.outer, regular: false,
                       model: model(names: ["Alexandra", "Bartholomew", "Christopher", "Dominique", "Evangeline", "Fitzgerald"], rounds: 6, tenRule: true))
    }

    func testRoundInputSheetAccessibilityTextSize() throws {
        let m = model(names: ["Alexandra", "Bartholomew", "Christopher", "Dominique"], rounds: 6, tenRule: true)
        _ = try render("sheet-compact-4p-10d-ax3", size: Self.outer, regular: false, model: m,
                       category: .accessibilityExtraLarge,
                       root: AnyView(RoundInputView(model: m, presentation: .sheet)))
    }

    func testRoundInputSheetDefaultTextSize() throws {
        let m = model(names: ["Alexandra", "Bartholomew", "Christopher", "Dominique"], rounds: 6, tenRule: true)
        _ = try render("sheet-compact-4p-10d-default", size: Self.outer, regular: false, model: m,
                       root: AnyView(RoundInputView(model: m, presentation: .sheet)))
    }

    // MARK: Undo toast and edit round (visual review only: PNGs)

    func testUndoToastCompact() throws {
        let m = model(names: ["Ace", "Deuce", "Trey", "Queen"], rounds: 5)
        _ = try render("toast-compact", size: Self.outer, regular: false, model: m,
                       root: AnyView(GameView(model: m, initialUndoToast: "Round 6 undone")))
    }

    func testUndoToastCompactDark() throws {
        let m = model(names: ["Ace", "Deuce", "Trey", "Queen"], rounds: 5)
        _ = try render("toast-compact-dark", size: Self.outer, regular: false, model: m, dark: true,
                       root: AnyView(GameView(model: m, initialUndoToast: "Round 6 undone")))
    }

    func testUndoToastSplit() throws {
        let m = model(names: ["Ace", "Deuce", "Trey", "Queen"], rounds: 5)
        _ = try render("toast-split", size: Self.innerPortrait, regular: true, model: m,
                       root: AnyView(GameView(model: m, initialUndoToast: "Round 6 undone")))
    }

    func testEditRoundSheetCompact() throws {
        let m = model(names: ["Alexandra", "Bartholomew", "Christopher", "Dominique"], rounds: 6, tenRule: true)
        _ = try render("edit-round-compact", size: Self.outer, regular: false, model: m,
                       root: AnyView(RoundInputView(model: m, presentation: .sheet, editingHandID: m.game.hands[2].id)))
    }

    func testEditRoundSheetCompactDark() throws {
        let m = model(names: ["Ace", "Deuce", "Trey", "Queen"], rounds: 6)
        _ = try render("edit-round-compact-dark", size: Self.outer, regular: false, model: m, dark: true,
                       root: AnyView(RoundInputView(model: m, presentation: .sheet, editingHandID: m.game.hands[3].id)))
    }

    // MARK: Empty board, 26 highlight, Increase Contrast (visual review only: PNGs)

    func testOuterEmptyBoardLight() throws {
        _ = try render("outer-empty-board", size: Self.outer, regular: false,
                       model: model(names: ["Ace", "Deuce", "Trey", "Queen"], rounds: 0))
    }

    func testOuterEmptyBoardDark() throws {
        _ = try render("outer-empty-board-dark", size: Self.outer, regular: false,
                       model: model(names: ["Ace", "Deuce", "Trey", "Queen"], rounds: 0), dark: true)
    }

    /// Round 3 is a moon by Ace: the three other players take 26 each, which gets the orange highlight.
    private func modelWithMoonVictims() -> GameViewModel {
        let ps = players(["Ace", "Deuce", "Trey", "Queen"])
        var hs = hands(for: ps, rounds: 2)
        var moon: [UUID: Int] = [:]
        ps.forEach { moon[$0.id] = 26 }
        moon[ps[0].id] = 0
        hs.append(.init(id: UUID(), pointsByPlayerID: moon, notes: "", createdAt: Date()))
        hs.append(contentsOf: hands(for: ps, rounds: 4).suffix(1))
        return GameViewModel(initialState: SyncableState(game: HeartsGame(players: ps, hands: hs), settings: GameSettings(), firstDealerIndex: 0))
    }

    func testOuterMoonVictim26HighlightDark() throws {
        _ = try render("outer-26-highlight-dark", size: Self.outer, regular: false, model: modelWithMoonVictims(), dark: true)
    }

    func testOuterMoonVictim26HighlightLight() throws {
        _ = try render("outer-26-highlight-light", size: Self.outer, regular: false, model: modelWithMoonVictims())
    }

    func testOuterIncreaseContrastLight() throws {
        _ = try render("outer-increase-contrast-light", size: Self.outer, regular: false,
                       model: modelWithMoonVictims(), highContrast: true)
    }

    func testOuterIncreaseContrastDark() throws {
        _ = try render("outer-increase-contrast-dark", size: Self.outer, regular: false,
                       model: modelWithMoonVictims(), dark: true, highContrast: true)
    }

    func testEditRoundTotalsExcludeEditedHand() throws {
        // Round 3 (the moon) is being edited: the badges must not include its 26s.
        let m = modelWithMoonVictims()
        _ = try render("edit-round-totals", size: Self.outer, regular: false, model: m,
                       root: AnyView(RoundInputView(model: m, presentation: .sheet, editingHandID: m.game.hands[2].id)))
    }

    // MARK: History (visual review only: PNGs)

    private func history(_ names: [String], rounds: Int, tenRule: Bool) -> [CompletedGame] {
        let ps = players(names)
        let hs = hands(for: ps, rounds: rounds, tenRule: tenRule)
        let g1 = CompletedGame(finishedAt: Date().addingTimeInterval(-3600), game: HeartsGame(players: ps, hands: hs),
                               settings: GameSettings(tenOfDiamondsMinus10: tenRule))
        // Second game with the same names (different case) and a tie-free result.
        let ps2 = ps.map { HeartsGame.Player(id: UUID(), name: $0.name.uppercased()) }
        let g2 = CompletedGame(finishedAt: Date().addingTimeInterval(-90_000),
                               game: HeartsGame(players: ps2, hands: hands(for: ps2, rounds: rounds + 2, tenRule: false)),
                               settings: GameSettings(endingScore: 75))
        return [g1, g2]
    }

    private func renderHistoryDetail(_ name: String, size: CGSize, regular: Bool, dark: Bool, names: [String], rounds: Int, tenRule: Bool) throws {
        let c = history(names, rounds: rounds, tenRule: tenRule)[0]
        _ = try render(name, size: size, regular: regular, model: model(names: names, rounds: 1), dark: dark,
                       root: AnyView(NavigationStack { HistoryDetailView(completedGame: c) }), cancelSideInsets: true)
    }

    func testHistoryDetailCompactLight() throws {
        try renderHistoryDetail("history-detail-compact-light", size: Self.outer, regular: false, dark: false,
                                names: ["Ace", "Deuce", "Trey", "Queen"], rounds: 8, tenRule: true)
    }

    func testHistoryDetailCompactDark() throws {
        try renderHistoryDetail("history-detail-compact-dark", size: Self.outer, regular: false, dark: true,
                                names: ["Alexandra", "Bartholomew", "Christopher", "Dominique", "Evangeline", "Fitzgerald"], rounds: 8, tenRule: true)
    }

    func testHistoryDetailRegularLight() throws {
        try renderHistoryDetail("history-detail-regular-light", size: Self.innerPortrait, regular: true, dark: false,
                                names: ["Ace", "Deuce", "Trey", "Queen"], rounds: 8, tenRule: true)
    }

    func testHistoryDetailRegularDark() throws {
        try renderHistoryDetail("history-detail-regular-dark", size: Self.innerPortrait, regular: true, dark: true,
                                names: ["Ace", "Deuce", "Trey", "Queen"], rounds: 8, tenRule: false)
    }

    private func renderLeaderboard(_ name: String, size: CGSize, regular: Bool, dark: Bool) throws {
        let m = GameViewModel(initialState: SyncableState(
            game: HeartsGame(players: players(["Ace", "Deuce"])),
            settings: GameSettings(), firstDealerIndex: 0,
            history: history(["Ace", "Deuce", "Trey", "Queen"], rounds: 6, tenRule: true)))
        _ = try render(name, size: size, regular: regular, model: m, dark: dark,
                       root: AnyView(NavigationStack { PlayersLeaderboardView(records: m.history.playerRecords).navigationTitle("Players") }), cancelSideInsets: true)
    }

    func testLeaderboardCompactLight() throws {
        try renderLeaderboard("leaderboard-compact-light", size: Self.outer, regular: false, dark: false)
    }

    func testLeaderboardCompactDark() throws {
        try renderLeaderboard("leaderboard-compact-dark", size: Self.outer, regular: false, dark: true)
    }

    func testLeaderboardRegularLight() throws {
        try renderLeaderboard("leaderboard-regular-light", size: Self.innerPortrait, regular: true, dark: false)
    }

    func testLeaderboardRegularDark() throws {
        try renderLeaderboard("leaderboard-regular-dark", size: Self.innerPortrait, regular: true, dark: true)
    }
}
