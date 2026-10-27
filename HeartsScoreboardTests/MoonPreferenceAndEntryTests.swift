import XCTest
@testable import HeartsScoreboard

/// The shoot-the-moon preference lives in Settings now (and in the round-entry header menu): it must still
/// round-trip through settings coding and iCloud sync, and the value picker keeps the stepper's clamp.
@MainActor
final class MoonPreferenceAndEntryTests: XCTestCase {
    private let players = ["A", "B", "C", "D"].map { HeartsGame.Player(id: UUID(), name: $0) }

    func testPreferenceRoundTripsThroughSettingsCoding() throws {
        var settings = GameSettings()
        settings.shootMoonPreference = .subtract26
        let decoded = try JSONDecoder().decode(GameSettings.self, from: JSONEncoder().encode(settings))
        XCTAssertEqual(decoded.shootMoonPreference, .subtract26)
    }

    func testPreferenceIsSyncedViaICloudPayload() throws {
        let state = SyncableState(game: HeartsGame(players: players),
                                  settings: GameSettings(shootMoonPreference: .subtract26, appearance: .dark),
                                  firstDealerIndex: 0)
        let decoded = try JSONDecoder().decode(SyncableState.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(decoded.settings.shootMoonPreference, .subtract26)
        XCTAssertEqual(decoded.settings.appearance, .system, "appearance stays local")
    }

    func testPreferenceLabelsAreDistinct() {
        XCTAssertNotEqual(ShootMoonPreference.add26.label, ShootMoonPreference.subtract26.label)
        XCTAssertNotEqual(ShootMoonPreference.add26.detailLabel, ShootMoonPreference.subtract26.detailLabel)
    }

    func testSetPointsClampsToZeroThroughTwentySix() {
        var e = RoundEntryState()
        e.reset(players: players)
        let id = players[0].id
        e.setPoints(for: id, to: 40)
        XCTAssertEqual(e.points[id], 26)
        e.setPoints(for: id, to: -3)
        XCTAssertEqual(e.points[id], 0)
        e.setPoints(for: id, to: 13)
        XCTAssertEqual(e.points[id], 13)
        e.adjustPoints(for: id, delta: 20)
        XCTAssertEqual(e.points[id], 26)
        e.adjustPoints(for: id, delta: -50)
        XCTAssertEqual(e.points[id], 0)
    }

    func testMoonShooterDetection() {
        var e = RoundEntryState()
        e.reset(players: players)
        XCTAssertNil(e.moonShooterID(players: players))
        for p in players { e.points[p.id] = p.id == players[2].id ? 0 : 26 }
        XCTAssertTrue(e.isShootTheMoon(players: players))
        XCTAssertEqual(e.moonShooterID(players: players), players[2].id)
        for p in players { e.points[p.id] = p.id == players[1].id ? -26 : 0 }
        XCTAssertEqual(e.moonShooterID(players: players), players[1].id)
        e.reset(players: players)
        e.points[players[0].id] = 13
        e.points[players[1].id] = 13
        XCTAssertTrue(e.isRoundValid(players: players))
        XCTAssertFalse(e.isShootTheMoon(players: players))
        XCTAssertNil(e.moonShooterID(players: players))
    }
}
