import XCTest
import SwiftUI
import UIKit
@testable import HeartsScoreboard

/// Renders Settings and About at the compact (outer display) size to PNGs in $SNAPSHOT_DIR
/// (`TEST_RUNNER_SNAPSHOT_DIR=...`) for visual review. Models are in-memory and never persisted.
@MainActor
final class SettingsSnapshotTests: XCTestCase {
    private static let size = CGSize(width: 466, height: 678)

    private func model(withHistory: Bool) -> GameViewModel {
        let ps = ["Ace", "Deuce", "Trey", "Player 4"].map { HeartsGame.Player(id: UUID(), name: $0) }
        let past = ["Mo", "Lena", "Priya", "Sam"].map { HeartsGame.Player(id: UUID(), name: $0) }
        let history = withHistory ? [CompletedGame(game: HeartsGame(players: past), settings: GameSettings())] : []
        let m = GameViewModel(initialState: SyncableState(
            game: HeartsGame(players: ps), settings: GameSettings(tenOfDiamondsMinus10: true),
            firstDealerIndex: 0, history: history))
        m.persistsToCloud = false
        return m
    }

    private func render(_ name: String, dark: Bool, size: CGSize = SettingsSnapshotTests.size, root: AnyView) throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(origin: .zero, size: size)
        window.traitOverrides.horizontalSizeClass = .compact
        window.overrideUserInterfaceStyle = dark ? .dark : .light
        let host = UIHostingController(rootView: root)
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.frame = window.bounds
        host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.6))
        host.view.layoutIfNeeded()
        let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        let data = try XCTUnwrap(image.pngData())
        XCTAssertGreaterThan(data.count, 1000)
        let dir = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"] ?? NSTemporaryDirectory()
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        try data.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
    }

    func testSettingsLight() throws {
        try render("settings-light", dark: false, root: AnyView(SettingsView(model: model(withHistory: true))))
    }

    func testSettingsDark() throws {
        try render("settings-dark", dark: true, root: AnyView(SettingsView(model: model(withHistory: true))))
    }

    func testAboutLight() throws {
        try render("about-light", dark: false, root: AnyView(NavigationStack { AboutView() }))
    }

    func testAboutDark() throws {
        try render("about-dark", dark: true, root: AnyView(NavigationStack { AboutView() }))
    }

    // Tall renders show the sections below the fold.
    private static let tall = CGSize(width: 466, height: 1500)

    func testSettingsTallLight() throws {
        try render("settings-tall-light", dark: false, size: Self.tall, root: AnyView(SettingsView(model: model(withHistory: true))))
    }

    func testSettingsTallDark() throws {
        try render("settings-tall-dark", dark: true, size: Self.tall, root: AnyView(SettingsView(model: model(withHistory: true))))
    }

    func testAboutTallLight() throws {
        try render("about-tall-light", dark: false, size: Self.tall, root: AnyView(NavigationStack { AboutView() }))
    }

    func testAboutTallDark() throws {
        try render("about-tall-dark", dark: true, size: Self.tall, root: AnyView(NavigationStack { AboutView() }))
    }
}
