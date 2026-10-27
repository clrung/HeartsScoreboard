#if DEBUG
import XCTest
import SwiftUI
import UIKit
@testable import HeartsScoreboard

/// Renders GameView at iPad window sizes (the simulator can't be resized from the CLI) in light and dark,
/// for the scenarios the iPad redesign is judged on, and writes PNGs to $SNAPSHOT_DIR
/// (`TEST_RUNNER_SNAPSHOT_DIR=... xcodebuild test`) or the temp dir. Models are in-memory only.
@MainActor
final class IPadLayoutSnapshotTests: XCTestCase {
    private struct Size { let name: String; let size: CGSize; let regular: Bool }

    private static let sizes: [Size] = [
        Size(name: "13land", size: CGSize(width: 1376, height: 1032), regular: true),
        Size(name: "13port", size: CGSize(width: 1032, height: 1376), regular: true),
        Size(name: "11land", size: CGSize(width: 1210, height: 834), regular: true),
        Size(name: "11port", size: CGSize(width: 834, height: 1210), regular: true),
        Size(name: "miniland", size: CGSize(width: 1133, height: 744), regular: true),
        Size(name: "miniport", size: CGSize(width: 744, height: 1133), regular: true),
        Size(name: "third", size: CGSize(width: 507, height: 1032), regular: false),
    ]

    // MARK: Fixtures

    private func players(_ names: [String]) -> [HeartsGame.Player] { names.map { .init(id: UUID(), name: $0) } }

    private func hands(for players: [HeartsGame.Player], rounds: Int, tenRule: Bool) -> [HeartsGame.Hand] {
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
            let holder = tenRule ? (r == 3 ? a : players[(r + 2) % players.count].id) : nil
            if let holder { pts[holder, default: 0] -= 10 }
            return .init(id: UUID(), pointsByPlayerID: pts, notes: "", createdAt: Date(), tenOfDiamondsPlayerID: holder)
        }
    }

    private func model(names: [String], rounds: Int, tenRule: Bool = false, endingScore: Int = 100) -> GameViewModel {
        let ps = players(names)
        let game = HeartsGame(players: ps, hands: hands(for: ps, rounds: rounds, tenRule: tenRule))
        return GameViewModel(initialState: SyncableState(
            game: game,
            settings: GameSettings(endingScore: endingScore, tenOfDiamondsMinus10: tenRule),
            firstDealerIndex: 0
        ))
    }

    private let six = ["Ava", "Ben", "Cleo", "Drew", "Eli", "Frankie"]

    private func scenarios() -> [(String, GameViewModel)] {
        [
            ("6p-1round", ScreenshotDemo.makeModel(playerCount: 6, scenario: "early")),
            ("4p-3rounds", model(names: Array(six.prefix(4)), rounds: 3)),
            ("4p-20rounds", ScreenshotDemo.makeModel(playerCount: 4, scenario: "long")),
            ("tied", ScreenshotDemo.makeModel(playerCount: 4, scenario: "tied")),
            ("gameover", ScreenshotDemo.makeModel(playerCount: 4, scenario: "over")),
            ("3p", model(names: Array(six.prefix(3)), rounds: 5)),
            ("longnames", ScreenshotDemo.makeModel(playerCount: 6, scenario: "longnames")),
            ("tenrule", model(names: Array(six.prefix(4)), rounds: 6, tenRule: true)),
            ("empty", model(names: Array(six.prefix(4)), rounds: 0)),
        ]
    }

    // MARK: Harness

    private func render(_ name: String, size: CGSize, regular: Bool, model: GameViewModel, dark: Bool) throws -> UIImage {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(origin: .zero, size: size)
        window.traitOverrides.horizontalSizeClass = regular ? .regular : .compact
        window.traitOverrides.verticalSizeClass = .regular
        window.overrideUserInterfaceStyle = dark ? .dark : .light
        let host = UIHostingController(rootView: GameView(model: model))
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.frame = window.bounds
        host.view.layoutIfNeeded()
        // Replace the host scene's safe area with a plausible iPad one (home indicator only).
        let leaked = host.view.safeAreaInsets
        host.additionalSafeAreaInsets = UIEdgeInsets(
            top: -leaked.top + host.additionalSafeAreaInsets.top + 24,
            left: -leaked.left + host.additionalSafeAreaInsets.left,
            bottom: 20 - leaked.bottom + host.additionalSafeAreaInsets.bottom,
            right: -leaked.right + host.additionalSafeAreaInsets.right)
        host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.35))
        host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.15))

        let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        let data = try XCTUnwrap(image.pngData())
        XCTAssertGreaterThan(data.count, 1000)
        let dir = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"] ?? NSTemporaryDirectory()
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        try data.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
        window.isHidden = true
        return image
    }

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

    /// Calm felt: green-dominant, never the old lime (high green + high red/blue lightness).
    private func isCalmFelt(_ c: (r: CGFloat, g: CGFloat, b: CGFloat)) -> Bool {
        c.g > c.r && c.g > c.b && c.g < 0.45 && c.r < 0.25
    }

    // MARK: Tests

    func testRendersEveryScenarioAtEveryIPadSize() throws {
        for size in Self.sizes {
            for dark in [false, true] {
                for (scenario, model) in scenarios() {
                    let name = "ipad-\(size.name)-\(scenario)-\(dark ? "dark" : "light")"
                    let image = try render(name, size: size.size, regular: size.regular, model: model, dark: dark)
                    XCTAssertEqual(image.size.width, size.size.width, name)
                    // Margin above the header is felt, never lime or white.
                    XCTAssertTrue(isCalmFelt(pixel(image, 6, size.size.height - 6)), "\(name): felt at bottom-left edge")
                }
            }
        }
    }

    /// Equal panes (below 1100pt) keep the Duo fold rule: only felt across the vertical center line below the header.
    func testEqualPanesLeaveTheCenterGapClear() throws {
        for size in Self.sizes where size.regular && size.size.width < 1100 {
            let image = try render("ipad-center-\(size.name)", size: size.size, regular: true,
                                   model: ScreenshotDemo.makeModel(playerCount: 4, scenario: "long"), dark: false)
            for y in stride(from: size.size.height * 0.3, to: size.size.height * 0.9, by: 40) {
                XCTAssertTrue(isCalmFelt(pixel(image, size.size.width / 2, y)), "\(size.name): center line y=\(y)")
            }
        }
    }

    /// The scoreboard hugs its content: with one round the felt (not card) fills the lower part of its pane.
    func testScoreboardHugsContentAtLandscape() throws {
        let image = try render("ipad-hug", size: CGSize(width: 1376, height: 1032), regular: true,
                               model: ScreenshotDemo.makeModel(playerCount: 6, scenario: "early"), dark: false)
        XCTAssertTrue(isCalmFelt(pixel(image, 300, 900)), "felt below the short scoreboard card")
        let card = pixel(image, 300, 200) // inside the card, under the header row
        XCTAssertGreaterThan(card.r, 0.8)
    }

    func testPhoneWidthStillRenders() throws {
        for dark in [false, true] {
            for (scenario, model) in scenarios() {
                let image = try render("iphone-\(scenario)-\(dark ? "dark" : "light")", size: CGSize(width: 393, height: 852),
                                       regular: false, model: model, dark: dark)
                XCTAssertTrue(isCalmFelt(pixel(image, 4, 840)), scenario)
            }
        }
    }
}
#endif
