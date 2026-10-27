import SwiftUI

@main
struct HeartsScoreboardApp: App {
    var body: some Scene {
        WindowGroup {
            // The Appearance preference is applied to the window by `GameView` (`WindowAppearanceApplier`),
            // so the board and every sheet switch together.
            #if DEBUG
            if ScreenshotDemo.isEnabled {
                // `-screenshotFollowAppearance` (UI tests) honors the in-app picker instead of forcing a scheme.
                if ScreenshotDemo.followsAppearancePreference {
                    GameView(model: ScreenshotDemo.makeModel())
                } else {
                    GameView(model: ScreenshotDemo.makeModel())
                        .preferredColorScheme(ScreenshotDemo.forcedColorScheme)
                }
            } else {
                GameView()
            }
            #else
            GameView()
            #endif
        }
    }
}
