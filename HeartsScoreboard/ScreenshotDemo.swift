#if DEBUG
import SwiftUI

/// Deterministic, isolated app state for the App Store screenshot pipeline (DEBUG builds only).
///
/// Enabled with the `-screenshotDemo` launch argument. Optional `-screenshotAppearance light|dark`
/// forces the color scheme in memory. The demo model never reads iCloud and never writes iCloud
/// (`persistsToCloud == false`), and the appearance override is never written to UserDefaults.
enum ScreenshotDemo {
    static var isEnabled: Bool { CommandLine.arguments.contains("-screenshotDemo") }

    /// Forced scheme: `-screenshotAppearance dark` -> dark, anything else (or missing) -> light.
    static var forcedColorScheme: ColorScheme {
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "-screenshotAppearance"), args.indices.contains(i + 1), args[i + 1] == "dark" {
            return .dark
        }
        return .light
    }

    @MainActor
    static func makeModel() -> GameViewModel {
        // UI tests only: `-screenshotPlayerCount 5|6` adds players (long names stress narrow layouts).
        var names = ["Ava", "Ben", "Cleo", "Drew", "Alexandra", "Frankie"]
        if let i = CommandLine.arguments.firstIndex(of: "-screenshotPlayerCount"),
           CommandLine.arguments.indices.contains(i + 1), let n = Int(CommandLine.arguments[i + 1]), (3...6).contains(n) {
            names = Array(names.prefix(n))
        } else {
            names = Array(names.prefix(4))
        }
        let players = names.map { HeartsGame.Player(id: UUID(), name: $0) }

        func hand(_ points: [Int], at date: Date) -> HeartsGame.Hand {
            var map: [UUID: Int] = [:]
            for (i, p) in players.enumerated() { map[p.id] = points[i % points.count] }
            return .init(id: UUID(), pointsByPlayerID: map, notes: "", createdAt: date)
        }

        let base = date(2026, 10, 24, 19, 0)
        // In-progress game: includes a moon shot by Ben (round 6, "add 26"). Nobody is near 100.
        let live: [[Int]] = [
            [5, 8, 6, 7], [0, 13, 2, 11], [14, 3, 0, 9], [7, 0, 11, 8],
            [4, 9, 6, 7], [26, 0, 26, 26], [2, 12, 1, 11], [8, 5, 9, 4]
        ]
        let game = HeartsGame(players: players, hands: live.map { hand($0, at: base) })

        // Completed game for the history / Game Summary shot (Ben wins with 54).
        let done: [[Int]] = [
            [2, 7, 13, 4], [6, 5, 2, 13], [0, 18, 2, 6], [14, 6, 0, 6], [13, 0, 5, 8],
            [26, 0, 26, 26], [17, 0, 5, 4], [13, 1, 10, 2], [5, 15, 0, 6], [5, 2, 13, 6]
        ]
        let donePlayers = names.map { HeartsGame.Player(id: UUID(), name: $0) }
        var doneHands: [HeartsGame.Hand] = []
        for row in done {
            var map: [UUID: Int] = [:]
            for (i, p) in donePlayers.enumerated() { map[p.id] = row[i % row.count] }
            doneHands.append(.init(id: UUID(), pointsByPlayerID: map, notes: "", createdAt: date(2026, 10, 17, 20, 0)))
        }
        let completed = CompletedGame(
            finishedAt: date(2026, 10, 17, 20, 37),
            game: HeartsGame(players: donePlayers, hands: doneHands),
            settings: GameSettings()
        )

        var settings = GameSettings(quickIncrementPoints: 5)
        if forcedColorScheme == .dark { settings.appearance = .dark }
        // UI tests only: `-screenshotTenRule` turns on the 10♦ −10 rule.
        if CommandLine.arguments.contains("-screenshotTenRule") { settings.tenOfDiamondsMinus10 = true }
        let model = GameViewModel(game: game, settings: settings, firstDealerIndex: 0, history: [completed])
        model.persistsToCloud = false
        model.settings.appearance = settings.appearance // undo anything read from UserDefaults
        return model
    }

    private static func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min)) ?? Date(timeIntervalSince1970: 0)
    }
}
#endif
