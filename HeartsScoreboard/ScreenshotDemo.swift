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
    static func makeModel(playerCount: Int? = nil) -> GameViewModel {
        // UI tests only: `-screenshotPlayerCount 5|6` adds players (long names stress narrow layouts).
        var count = playerCount ?? 4
        if playerCount == nil, let i = CommandLine.arguments.firstIndex(of: "-screenshotPlayerCount"),
           CommandLine.arguments.indices.contains(i + 1), let n = Int(CommandLine.arguments[i + 1]) {
            count = n
        }
        if !(3...6).contains(count) { count = 4 }
        let names = Array(["Ava", "Ben", "Cleo", "Drew", "Alexandra", "Frankie"].prefix(count))
        let players = names.map { HeartsGame.Player(id: UUID(), name: $0) }

        func hand(_ points: [Int], at date: Date) -> HeartsGame.Hand {
            var map: [UUID: Int] = [:]
            let row = fit(points, to: players.count)
            for (i, p) in players.enumerated() { map[p.id] = row[i] }
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
            let row = fit(row, to: donePlayers.count)
            for (i, p) in donePlayers.enumerated() { map[p.id] = row[i] }
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

    /// Adapts a 4-player demo round to `count` players so it is still a legal round: a moon shot stays
    /// "shooter 0, everyone else 26"; otherwise the 26 points are kept by folding dropped players' points
    /// into the remaining ones (3 players) or splitting an existing player's points with each extra player
    /// (5–6). 4 players returns the row unchanged, so the App Store screenshots don't move.
    static func fit(_ row: [Int], to count: Int) -> [Int] {
        guard count != row.count else { return row }
        if row.filter({ $0 == 0 }).count == 1, row.allSatisfy({ $0 == 0 || $0 == 26 }) {
            let shooter = row.firstIndex(of: 0)!
            return (0..<count).map { $0 == shooter % count ? 0 : 26 }
        }
        var out = Array(row.prefix(count)) + Array(repeating: 0, count: max(0, count - row.count))
        for k in count..<max(count, row.count) { out[k % count] += row[k] }
        for k in row.count..<max(row.count, count) {
            let half = out[k - row.count] / 2
            out[k - row.count] -= half
            out[k] = half
        }
        return out
    }

    private static func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min)) ?? Date(timeIntervalSince1970: 0)
    }
}
#endif
