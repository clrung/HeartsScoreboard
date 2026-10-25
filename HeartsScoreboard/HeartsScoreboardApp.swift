import SwiftUI

@main
struct HeartsScoreboardApp: App {
    @AppStorage("HeartsScoreboardAppearancePreference") private var appearanceRaw: String = AppearancePreference.system.rawValue

    private var preferredScheme: ColorScheme? {
        guard let pref = AppearancePreference(rawValue: appearanceRaw) else { return nil }
        switch pref {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if ScreenshotDemo.isEnabled {
                GameView(model: ScreenshotDemo.makeModel())
                    .preferredColorScheme(ScreenshotDemo.forcedColorScheme)
            } else {
                GameView()
                    .preferredColorScheme(preferredScheme)
            }
            #else
            GameView()
                .preferredColorScheme(preferredScheme)
            #endif
        }
    }
}
