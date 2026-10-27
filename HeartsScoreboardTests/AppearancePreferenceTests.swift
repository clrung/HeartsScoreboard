import XCTest
@testable import HeartsScoreboard

final class AppearancePreferenceTests: XCTestCase {
    func testWindowStyleMapping() {
        XCTAssertEqual(AppearancePreference.system.userInterfaceStyle, .unspecified)
        XCTAssertEqual(AppearancePreference.light.userInterfaceStyle, .light)
        XCTAssertEqual(AppearancePreference.dark.userInterfaceStyle, .dark)
    }

    /// System must clear a previous Dark/Light override, not leave it in place.
    @MainActor
    func testApplierSetsAndClearsWindowOverride() {
        let window = UIWindow(frame: .init(x: 0, y: 0, width: 100, height: 100))
        let applier = WindowAppearanceApplier.ApplierView()
        window.addSubview(applier)
        applier.style = .dark
        applier.apply()
        XCTAssertEqual(window.overrideUserInterfaceStyle, .dark)
        applier.style = .unspecified
        applier.apply()
        XCTAssertEqual(window.overrideUserInterfaceStyle, .unspecified)
    }
}
