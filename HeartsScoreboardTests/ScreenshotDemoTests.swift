#if DEBUG
import XCTest
@testable import HeartsScoreboard

/// Regression: with `-screenshotPlayerCount 5|6` the demo wrapped the 4-player rows (`points[i % 4]`),
/// producing rounds that didn't total 26, which no real game can contain.
@MainActor
final class ScreenshotDemoTests: XCTestCase {
    func testFitKeepsFourPlayerRowsUnchanged() {
        XCTAssertEqual(ScreenshotDemo.fit([5, 8, 6, 7], to: 4), [5, 8, 6, 7])
    }

    func testFitKeepsNormalRoundsAt26ForEveryPlayerCount() {
        for row in [[5, 8, 6, 7], [0, 13, 2, 11], [14, 3, 0, 9], [13, 0, 5, 8]] {
            for n in 3...6 {
                let fitted = ScreenshotDemo.fit(row, to: n)
                XCTAssertEqual(fitted.count, n)
                XCTAssertEqual(fitted.reduce(0, +), 26, "\(row) for \(n) players")
                XCTAssertTrue(fitted.allSatisfy { $0 >= 0 })
            }
        }
    }

    func testFitKeepsMoonShotsAsMoonShots() {
        XCTAssertEqual(ScreenshotDemo.fit([26, 0, 26, 26], to: 6), [26, 0, 26, 26, 26, 26])
        XCTAssertEqual(ScreenshotDemo.fit([26, 0, 26, 26], to: 3), [26, 0, 26])
    }

    func testDemoGamesAreLegalWithSixPlayers() {
        let model = ScreenshotDemo.makeModel(playerCount: 6)
        let games = [model.game] + model.history.map(\.game)
        for game in games {
            XCTAssertEqual(game.players.count, 6)
            for hand in game.hands {
                let pts = game.players.map { hand.pointsByPlayerID[$0.id] ?? -1 }
                let isMoon = pts.filter { $0 == 0 }.count == 1 && pts.allSatisfy { $0 == 0 || $0 == 26 }
                XCTAssertTrue(isMoon || pts.reduce(0, +) == 26, "illegal demo round \(pts)")
            }
        }
    }
}
#endif
