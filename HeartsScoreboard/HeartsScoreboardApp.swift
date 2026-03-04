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
            GameView()
                .preferredColorScheme(preferredScheme)
        }
    }
}
