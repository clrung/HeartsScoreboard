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
                        dark: Bool = false, category: UIContentSizeCategory? = nil) throws -> Rendered {
        // A window without a scene doesn't render; attach to the host app's scene.
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(origin: .zero, size: size)
        window.traitOverrides.horizontalSizeClass = regular ? .regular : .compact
        window.traitOverrides.verticalSizeClass = regular ? .regular : .compact
        if size.width > size.height && !regular { window.traitOverrides.verticalSizeClass = .compact }
        window.overrideUserInterfaceStyle = dark ? .dark : .light
        if let category { window.traitOverrides.preferredContentSizeCategory = category }
        let host = UIHostingController(rootView: GameView(model: model))
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
        host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.5))
        host.view.layoutIfNeeded()

        print("SNAPDBG \(name) window=\(window.frame) host=\(host.view.frame) safe=\(host.view.safeAreaInsets) tc=\(host.traitCollection.horizontalSizeClass.rawValue) scale=\(host.traitCollection.displayScale)")
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

    /// The inline panel is a light, neutral (systemGroupedBackground) card on the green table.
    private func isPanelColor(_ c: (r: CGFloat, g: CGFloat, b: CGFloat), dark: Bool = false) -> Bool {
        if dark { return c.r < 0.15 && c.g < 0.15 && c.b < 0.15 && abs(c.g - c.r) < 0.03 }
        return min(c.r, c.g, c.b) > 0.9 && max(c.r, c.g, c.b) - min(c.r, c.g, c.b) < 0.04
    }

    /// Regular layout: inline round-entry panel on the right (just right of the center gap), and
    /// nothing but table background across the vertical center line.
    private func assertSplit(_ r: Rendered, dark: Bool = false, line: UInt = #line) {
        let size = r.image.size
        let panel = pixel(r.image, size.width * 0.75, 125) // "Round N" title row, inside the right card, below the header
        XCTAssertTrue(isPanelColor(panel, dark: dark), "inline panel expected in right pane, got \(panel)", line: line)
        for y in stride(from: CGFloat(160), to: size.height - 60, by: 40) {
            let c = pixel(r.image, size.width / 2, y)
            XCTAssertFalse(isPanelColor(c, dark: dark), "control/panel crosses center line at y=\(y): \(c)", line: line)
        }
    }

    // MARK: Tests

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
        let r = try render("inner-gameover-portrait", size: Self.innerPortrait, regular: true, model: m)
        XCTAssertFalse(isPanelColor(pixel(r.image, 669 * 0.75, 125)), "game over hides the inline entry panel")
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

    func testInner6PlayersTenRuleMoonDefaultSize() throws {
        _ = try render("outer-compact-6p-10d-default", size: Self.outer, regular: false,
                       model: model(names: ["Alexandra", "Bartholomew", "Christopher", "Dominique", "Evangeline", "Fitzgerald"], rounds: 6, tenRule: true))
    }
}
