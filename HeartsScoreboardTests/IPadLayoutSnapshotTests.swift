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
        Size(name: "11port", size: CGSize(width: 834, height: 1194), regular: true),
        Size(name: "miniland", size: CGSize(width: 1133, height: 744), regular: true),
        Size(name: "miniport", size: CGSize(width: 744, height: 1133), regular: true),
        Size(name: "third", size: CGSize(width: 507, height: 1032), regular: false),
        Size(name: "duoP", size: CGSize(width: 669, height: 951), regular: true),
        Size(name: "duoL", size: CGSize(width: 951, height: 669), regular: true),
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
        try renderView(name, size: size, regular: regular, dark: dark, view: GameView(model: model))
    }

    private func renderView<V: View>(_ name: String, size: CGSize, regular: Bool, dark: Bool,
                                     category: UIContentSizeCategory? = nil, highContrast: Bool = false, settle: TimeInterval = 0.15,
                                     view: V) throws -> UIImage {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(origin: .zero, size: size)
        window.traitOverrides.horizontalSizeClass = regular ? .regular : .compact
        window.traitOverrides.verticalSizeClass = .regular
        window.overrideUserInterfaceStyle = dark ? .dark : .light
        if let category { window.traitOverrides.preferredContentSizeCategory = category }
        if highContrast { window.traitOverrides.accessibilityContrast = .high }
        let host = UIHostingController(rootView: view)
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
        RunLoop.main.run(until: Date().addingTimeInterval(settle))

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

    /// Equal panes (below 1100pt, not stacked) keep the Duo fold rule: only felt across the vertical center line below the header.
    func testEqualPanesLeaveTheCenterGapClear() throws {
        for size in Self.sizes where size.regular && size.size.width < 1100
            && !GameView.usesStackedPanes(width: size.size.width, height: size.size.height) {
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

    /// The round-entry sheet as shown on iPhone (393x852, SE 375x667), light/dark, 3 and 6 players, long names,
    /// 10♦ rule and accessibility3 text. The sheet is NavigationStack content, so it renders full height here.
    func testRoundEntrySheetRendersOnPhones() throws {
        let phones: [(String, CGSize)] = [("15", CGSize(width: 393, height: 852)), ("se", CGSize(width: 375, height: 667))]
        for (phone, size) in phones {
            for dark in [false, true] {
                let cases: [(String, GameViewModel, UIContentSizeCategory?)] = [
                    ("4p", model(names: Array(six.prefix(4)), rounds: 3), nil),
                    ("3p", model(names: Array(six.prefix(3)), rounds: 2), nil),
                    ("6p-ten", model(names: six, rounds: 4, tenRule: true), nil),
                    ("longnames", ScreenshotDemo.makeModel(playerCount: 6, scenario: "longnames"), nil),
                    ("ax3", model(names: Array(six.prefix(4)), rounds: 3), .accessibilityLarge),
                ]
                for (tag, m, category) in cases {
                    if phone == "se" && !["4p", "6p-ten", "ax3"].contains(tag) { continue }
                    let image = try renderView("sheet-\(phone)-\(tag)-\(dark ? "dark" : "light")", size: size, regular: false,
                                               dark: dark, category: category, view: RoundInputView(model: m))
                    XCTAssertEqual(image.size.width, size.width)
                }
            }
        }
    }

    /// The 0...26 value picker, as in the popover.
    func testPointsGridPickerRenders() throws {
        for dark in [false, true] {
            _ = try renderView("valuegrid-\(dark ? "dark" : "light")", size: CGSize(width: 340, height: 260), regular: false, dark: dark,
                               view: PointsGridPicker(current: 13) { _ in }.background(Theme.cardSurface))
        }
    }

    func testHistoryDetailRendersOnTheCardTokens() throws {
        let ps = players(Array(six.prefix(4)))
        let completed = CompletedGame(finishedAt: Date(), game: HeartsGame(players: ps, hands: hands(for: ps, rounds: 8, tenRule: true)),
                                      settings: GameSettings(endingScore: 100, tenOfDiamondsMinus10: true))
        for dark in [false, true] {
            _ = try renderView("history-detail-\(dark ? "dark" : "light")", size: CGSize(width: 834, height: 1210), regular: true, dark: dark,
                               view: NavigationStack { HistoryDetailView(completedGame: completed) })
        }
    }

    /// Phase 3: the scoreboard's pending row mirrors the entry panel; a keyboard-selected row shows a ring.
    func testPendingRowAndKeyboardSelectionRender() throws {
        let sizes: [(String, CGSize)] = [("13land", CGSize(width: 1376, height: 1032)), ("11port", CGSize(width: 834, height: 1210))]
        for (sizeName, size) in sizes {
            for dark in [false, true] {
                let tag = dark ? "dark" : "light"
                for (name, count, rounds) in [("4p", 4, 3), ("6p-early", 6, 1)] {
                    let m: GameViewModel = count == 6
                        ? ScreenshotDemo.makeModel(playerCount: 6, scenario: "early")
                        : model(names: Array(six.prefix(4)), rounds: rounds)
                    let ps = m.game.players
                    var partial = RoundEntryState()
                    partial.reset(players: ps)
                    partial.setPoints(for: ps[0].id, to: 5)
                    partial.addQueenOfSpades(for: ps[1].id)
                    _ = try renderView("pending-partial-\(name)-\(sizeName)-\(tag)", size: size, regular: true, dark: dark,
                                       view: GameView(model: m, initialPending: partial))

                    var moon = RoundEntryState()
                    moon.reset(players: ps)
                    moon.applyShootMoon(shooterID: ps[2].id, players: ps, preference: m.settings.shootMoonPreference)
                    _ = try renderView("pending-moon-\(name)-\(sizeName)-\(tag)", size: size, regular: true, dark: dark,
                                       view: GameView(model: m, initialPending: moon))

                    _ = try renderView("pending-keyboard-\(name)-\(sizeName)-\(tag)", size: size, regular: true, dark: dark,
                                       view: GameView(model: m, initialPending: partial,
                                                      initialKeyboard: RoundEntryKeyboard(selectedIndex: 1, isActive: true)))
                }
            }
        }
    }


    // MARK: Phase 4

    /// Portrait iPad stacks the panes; narrower windows (Duo 669x951) and landscape do not.
    func testStackedPaneDecision() {
        XCTAssertTrue(GameView.usesStackedPanes(width: 834, height: 1194), "11in portrait")
        XCTAssertTrue(GameView.usesStackedPanes(width: 1032, height: 1376), "13in portrait")
        XCTAssertTrue(GameView.usesStackedPanes(width: 744, height: 1133), "mini portrait")
        XCTAssertFalse(GameView.usesStackedPanes(width: 669, height: 951), "Duo inner portrait keeps the fold gap")
        XCTAssertFalse(GameView.usesStackedPanes(width: 951, height: 669), "Duo inner landscape")
        XCTAssertFalse(GameView.usesStackedPanes(width: 1210, height: 834), "landscape")
        XCTAssertFalse(GameView.usesStackedPanes(width: 743, height: 1133), "below 744pt")
    }

    /// The entry card gets room first (up to ~half the height goes to the board).
    func testStackedBoardHeightLeavesRoomForTheEntryCard() {
        let avail: CGFloat = 1084
        XCTAssertEqual(GameView.stackedBoardMaxHeight(available: avail, entryEstimate: 480, gap: 16), avail * 0.52, accuracy: 0.5)
        XCTAssertEqual(GameView.stackedBoardMaxHeight(available: avail, entryEstimate: 700, gap: 16), avail - 716, accuracy: 0.5)
        XCTAssertGreaterThanOrEqual(GameView.stackedBoardMaxHeight(available: avail, entryEstimate: 2000, gap: 16), avail * 0.3)
    }

    /// 11in portrait, six players: names show in full (the earlier side-by-side layout squeezed them to initials)
    /// and the entry card fills the width.
    func testPortraitSixPlayersShowFullNames() throws {
        let names = ["Ava", "Ben", "Cleo", "Drew", "Alexandra", "Frankie"]
        let m = ScreenshotDemo.makeModel(playerCount: 6, scenario: "early")
        XCTAssertEqual(m.game.players.map(\.name), names)
        _ = try render("p4-11port-6p", size: CGSize(width: 834, height: 1194), regular: true, model: m, dark: false)
        // Shown names fit: column = (786 - 32 - 30) / 6 = 120pt; "Frankie" fits with the dealer badge.
        XCTAssertTrue(ScoreboardCard.nameFits(textWidth: 62, columnWidth: 120, hasDealerBadge: true))
        XCTAssertFalse(ScoreboardCard.nameFits(textWidth: 62, columnWidth: 61, hasDealerBadge: true), "Duo 6p columns use initials")
    }

    /// The crown badge reaches only into the well's inset, never the digits, at every Dynamic Type scale.
    func testCrownStaysClearOfDigits() {
        for crown in stride(from: CGFloat(11), through: 40, by: 1) {
            XCTAssertLessThan(CrownGeometry.reachIntoWell(), CrownGeometry.wellInset, "crown \(crown)")
            XCTAssertGreaterThanOrEqual(CrownGeometry.headroom(crownSize: crown), CrownGeometry.lift(crownSize: crown) , "headroom \(crown)")
        }
    }

    private struct QACase {
        var name: String
        var size: CGSize
        var regular = true
        var scenario = "4p-3"
        var dark = false
        var contrast = false
        var category: UIContentSizeCategory?
        var pending = false
        var keyboard = false
        var rtl = false
    }

    private func qaModel(_ key: String) -> GameViewModel {
        switch key {
        case "3p": return model(names: Array(six.prefix(3)), rounds: 5)
        case "4p-3": return model(names: Array(six.prefix(4)), rounds: 3)
        case "4p-0": return model(names: Array(six.prefix(4)), rounds: 0)
        case "6p-0": return model(names: six, rounds: 0)
        case "6p-1": return ScreenshotDemo.makeModel(playerCount: 6, scenario: "early")
        case "6p-22": return model(names: six, rounds: 22, endingScore: 500)
        case "4p-long": return ScreenshotDemo.makeModel(playerCount: 4, scenario: "long")
        case "tenrule": return model(names: Array(six.prefix(4)), rounds: 6, tenRule: true)
        case "6p-ten": return model(names: six, rounds: 5, tenRule: true)
        case "moon": return model(names: Array(six.prefix(4)), rounds: 5)
        case "tied", "over", "longnames": return ScreenshotDemo.makeModel(playerCount: key == "longnames" ? 6 : 4, scenario: key)
        default: fatalError(key)
        }
    }

    private func renderQA(_ c: QACase) throws {
        let m = qaModel(c.scenario)
        var pending: RoundEntryState?
        if c.pending {
            var p = RoundEntryState()
            p.reset(players: m.game.players)
            p.setPoints(for: m.game.players[0].id, to: 5)
            p.addQueenOfSpades(for: m.game.players[1].id)
            pending = p
        }
        let game = GameView(model: m, initialPending: pending,
                            initialKeyboard: c.keyboard ? RoundEntryKeyboard(selectedIndex: 1, isActive: true) : RoundEntryKeyboard())
        if c.rtl {
            _ = try renderView("qa-\(c.name)", size: c.size, regular: c.regular, dark: c.dark, category: c.category,
                               highContrast: c.contrast, view: game.environment(\.layoutDirection, .rightToLeft))
        } else {
            _ = try renderView("qa-\(c.name)", size: c.size, regular: c.regular, dark: c.dark, category: c.category,
                               highContrast: c.contrast, view: game)
        }
    }

    /// Visual QA matrix (Phase 4). Set QA_FILTER to a substring to render a subset.
    func testVisualQAMatrix() throws {
        let sizes: [(String, CGSize, Bool)] = [
            ("13land", CGSize(width: 1376, height: 1032), true), ("13port", CGSize(width: 1032, height: 1376), true),
            ("11land", CGSize(width: 1210, height: 834), true), ("11port", CGSize(width: 834, height: 1194), true),
            ("miniland", CGSize(width: 1133, height: 744), true), ("miniport", CGSize(width: 744, height: 1133), true),
            ("third507", CGSize(width: 507, height: 1032), false), ("third375", CGSize(width: 375, height: 1032), false),
            ("slide320", CGSize(width: 320, height: 1024), false),
            ("iphone", CGSize(width: 393, height: 852), false), ("se", CGSize(width: 375, height: 667), false),
            ("duoP", CGSize(width: 669, height: 951), true), ("duoL", CGSize(width: 951, height: 669), true),
            ("duoOuter", CGSize(width: 466, height: 678), false),
        ]
        var cases: [QACase] = []
        for (n, sz, reg) in sizes {
            for scen in ["3p", "4p-3", "6p-1", "6p-22", "longnames", "4p-0", "over"] {
                cases.append(QACase(name: "\(n)-\(scen)-light", size: sz, regular: reg, scenario: scen))
            }
            for scen in ["6p-22", "tied", "tenrule", "moon"] {
                cases.append(QACase(name: "\(n)-\(scen)-dark", size: sz, regular: reg, scenario: scen, dark: true))
            }
            cases.append(QACase(name: "\(n)-6p-1-pending-light", size: sz, regular: reg, scenario: "6p-1", pending: true, keyboard: true))
            cases.append(QACase(name: "\(n)-4p-3-pending-dark", size: sz, regular: reg, scenario: "4p-3", dark: true, pending: true))
            cases.append(QACase(name: "\(n)-4p-long-hc-light", size: sz, regular: reg, scenario: "4p-long", contrast: true))
            cases.append(QACase(name: "\(n)-6p-ten-hc-dark", size: sz, regular: reg, scenario: "6p-ten", dark: true, contrast: true))
            cases.append(QACase(name: "\(n)-4p-3-rtl", size: sz, regular: reg, scenario: "4p-3", rtl: true))
            for (cn, cat) in [("xs", UIContentSizeCategory.extraSmall), ("xxxl", .extraExtraExtraLarge), ("ax3", .accessibilityExtraLarge)] {
                cases.append(QACase(name: "\(n)-4p-3-\(cn)-light", size: sz, regular: reg, scenario: "4p-3", category: cat))
                cases.append(QACase(name: "\(n)-6p-22-\(cn)-dark", size: sz, regular: reg, scenario: "6p-22", dark: true, category: cat))
            }
        }
        let filter = ProcessInfo.processInfo.environment["QA_FILTER"]
        guard let filter, !filter.isEmpty else { return } // opt-in: the matrix is large
        for c in cases where c.name.contains(filter) { try renderQA(c) }
    }


    /// Phase 4: Settings (moon rule), History list/detail and the edit-round sheet as presented on iPad and iPhone.
    func testSheetsRenderOnIPadAndPhone() throws {
        let sizes: [(String, CGSize, Bool)] = [("ipad", CGSize(width: 834, height: 1194), true), ("iphone", CGSize(width: 393, height: 852), false)]
        for (tag, size, regular) in sizes {
            for dark in [false, true] {
                let scheme = dark ? "dark" : "light"
                let m = model(names: Array(six.prefix(4)), rounds: 6, tenRule: true)
                m.persistsToCloud = false
                m.history = [CompletedGame(finishedAt: Date(), game: m.game, settings: m.settings),
                             CompletedGame(finishedAt: Date().addingTimeInterval(-86400), game: m.game, settings: m.settings)]
                _ = try renderView("sheet-settings-\(tag)-\(scheme)", size: size, regular: regular, dark: dark, view: SettingsView(model: m))
                _ = try renderView("sheet-history-\(tag)-\(scheme)", size: size, regular: regular, dark: dark, view: HistoryView(model: m))
                _ = try renderView("sheet-edit-\(tag)-\(scheme)", size: size, regular: regular, dark: dark, settle: 1.0, view: RoundInputView(model: m, editingHandID: m.game.hands[2].id))
                _ = try renderView("sheet-historydetail-\(tag)-\(scheme)", size: size, regular: regular, dark: dark,
                                   view: NavigationStack { HistoryDetailView(completedGame: m.history[0]) })
            }
        }
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
