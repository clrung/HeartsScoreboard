import SwiftUI
import UIKit

/// Felt-green brand palette and design tokens shared by every screen. The accent itself lives in
/// `Assets.xcassets/AccentColor` (light #1F7A3B, dark #389E57) and is the app-wide tint.
enum Theme {
    static let accent = Color.accentColor

    // MARK: - Tokens

    /// 4-pt spacing scale.
    enum Spacing {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    enum Radius {
        /// Big cards (scoreboard, entry panel).
        static let card: CGFloat = 24
        /// Wells that hold a number (leader total).
        static let well: CGFloat = 12
        /// Highlighted score cells.
        static let cell: CGFloat = 8
    }

    /// Card shadow, so the scoreboard and entry panel share one elevation.
    enum Elevation {
        static func card(for colorScheme: ColorScheme) -> (color: Color, radius: CGFloat, y: CGFloat) {
            (Color.black.opacity(colorScheme == .dark ? 0.5 : 0.22), 20, 10)
        }
    }

    // MARK: - Semantic colors

    /// Dynamic color: light / dark, each with an increased-contrast variant (nil = same as the standard one).
    private static func dynamic(
        light: (CGFloat, CGFloat, CGFloat, CGFloat),
        dark: (CGFloat, CGFloat, CGFloat, CGFloat),
        lightHC: (CGFloat, CGFloat, CGFloat, CGFloat)? = nil,
        darkHC: (CGFloat, CGFloat, CGFloat, CGFloat)? = nil
    ) -> Color {
        Color(uiColor: UIColor { traits in
            let isDark = traits.userInterfaceStyle == .dark
            let high = traits.accessibilityContrast == .high
            let c = isDark ? (high ? darkHC ?? dark : dark) : (high ? lightHC ?? light : light)
            return UIColor(red: c.0, green: c.1, blue: c.2, alpha: c.3)
        })
    }

    /// Top and bottom of the felt. White text on either end is >= 6.9:1 (light) / > 11:1 (dark).
    static let feltTop = dynamic(light: (0.12, 0.36, 0.26, 1), dark: (0.06, 0.19, 0.14, 1),
                                 lightHC: (0.05, 0.28, 0.17, 1), darkHC: (0.02, 0.12, 0.08, 1))
    static let feltBottom = dynamic(light: (0.07, 0.27, 0.19, 1), dark: (0.03, 0.12, 0.09, 1),
                                    lightHC: (0.03, 0.22, 0.13, 1), darkHC: (0.01, 0.09, 0.06, 1))
    static let felt = feltTop

    /// Scoreboard card.
    static let cardSurface = dynamic(light: (0.97, 0.98, 0.96, 1), dark: (0.11, 0.15, 0.13, 1),
                                     lightHC: (1, 1, 1, 1), darkHC: (0.05, 0.08, 0.06, 1))
    /// Recessed area of the card (standings header).
    static let cardInset = dynamic(light: (0.90, 0.94, 0.91, 1), dark: (0.08, 0.11, 0.09, 1),
                                   lightHC: (0.92, 0.94, 0.92, 1), darkHC: (0.12, 0.16, 0.13, 1))
    /// Alternate round-row background (full width).
    static let rowZebra = dynamic(light: (0.0, 0.2, 0.1, 0.055), dark: (1, 1, 1, 0.055),
                                  lightHC: (0.0, 0.2, 0.1, 0.10), darkHC: (1, 1, 1, 0.12))
    /// Gold crown and leader accents. Always paired with a crown symbol, never color alone.
    static let leader = Color(red: 0.96, green: 0.76, blue: 0.20)
    /// Tint of the leader's total well.
    static let leaderWell = dynamic(light: (0.96, 0.76, 0.20, 0.22), dark: (0.96, 0.76, 0.20, 0.20),
                                    lightHC: (0.96, 0.76, 0.20, 0.38), darkHC: (0.96, 0.76, 0.20, 0.34))
    /// Shoot-the-moon symbol. >= 4.5:1 on the card in both appearances.
    static let moon = dynamic(light: (0.30, 0.27, 0.72, 1), dark: (0.66, 0.64, 1.0, 1),
                              lightHC: (0.22, 0.19, 0.60, 1), darkHC: (0.76, 0.75, 1.0, 1))
    /// Moon-tinted chip label: a touch deeper than `moon` in light so it holds >= 4.5:1 on the stronger chip tint.
    static let moonText = dynamic(light: (0.24, 0.21, 0.62, 1), dark: (0.66, 0.64, 1.0, 1),
                                  lightHC: (0.18, 0.15, 0.52, 1), darkHC: (0.80, 0.79, 1.0, 1))
    /// Accent-tinted chip label. The plain accent is ~3.8:1 (light) / ~4.3:1 (dark) on its own 14% tint, so chip
    /// text uses this deeper (light) / lighter (dark) green: >= 5:1 / >= 7:1 on the tint.
    static let accentText = dynamic(light: (0.09, 0.40, 0.19, 1), dark: (0.36, 0.80, 0.49, 1),
                                    lightHC: (0.05, 0.30, 0.12, 1), darkHC: (0.55, 0.90, 0.65, 1))
    /// Label color on a solid `moon` fill (selected moon chip).
    static let moonOnFill = dynamic(light: (1, 1, 1, 1), dark: (0.10, 0.09, 0.25, 1),
                                    lightHC: (1, 1, 1, 1), darkHC: (0.05, 0.04, 0.18, 1))
    /// Keyboard-selected player row in the round-entry panel (ring + faint wash). Hidden until a key is pressed.
    static let selectionRing = dynamic(light: (0.12, 0.48, 0.23, 1), dark: (0.42, 0.84, 0.55, 1),
                                       lightHC: (0.05, 0.32, 0.13, 1), darkHC: (0.60, 0.95, 0.70, 1))
    static let selectionWash = dynamic(light: (0.12, 0.48, 0.23, 0.08), dark: (0.42, 0.84, 0.55, 0.10),
                                       lightHC: (0.05, 0.32, 0.13, 0.12), darkHC: (0.60, 0.95, 0.70, 0.16))
    /// Live values in the scoreboard's pending row (subdued accent; >= 4.5:1 on the card).
    static let pendingValue = accentText
    /// "Took all 26" emphasis (cell tint) and near-the-end progress.
    static let allPointsWarning = Color.orange
    /// Fill behind a "took all 26" cell: a soft warm wash (peach in light, a low-opacity orange over the dark
    /// card), so a moon-less 26 reads as an event rather than an alarm. Pair with `allPointsText`.
    static let allPointsFill = dynamic(light: (1.0, 0.62, 0.18, 0.34), dark: (0.95, 0.50, 0.15, 0.24),
                                       lightHC: (1.0, 0.58, 0.12, 0.55), darkHC: (0.95, 0.50, 0.15, 0.34))
    /// Number on an `allPointsFill` cell (>= 7:1 in every variant).
    static let allPointsText = dynamic(light: (0.16, 0.08, 0.0, 1), dark: (1.0, 0.80, 0.56, 1),
                                       lightHC: (0.10, 0.05, 0.0, 1), darkHC: (1.0, 0.88, 0.70, 1))
    /// Positive / progress accent.
    static let positive = Color.accentColor

    // MARK: - Felt and card helpers (kept for existing call sites)

    /// Card-table background behind the game and history-detail screens: a deep, calm green with a very
    /// gentle vertical falloff. The scheme/contrast arguments pick the variant explicitly (the color tokens
    /// resolve against the given scheme), so views and the result-card renderer can force one.
    static func feltGradient(for colorScheme: ColorScheme, contrast: ColorSchemeContrast = .standard) -> LinearGradient {
        let traits = UITraitCollection(traitsFrom: [
            UITraitCollection(userInterfaceStyle: colorScheme == .dark ? .dark : .light),
            UITraitCollection(accessibilityContrast: contrast == .increased ? .high : .normal)
        ])
        let top = Color(uiColor: UIColor(feltTop).resolvedColor(with: traits))
        let bottom = Color(uiColor: UIColor(feltBottom).resolvedColor(with: traits))
        return LinearGradient(colors: [top, bottom], startPoint: .top, endPoint: .bottom)
    }

    /// Fill for the scoreboard card that sits on the felt (history detail uses the same one).
    static func scoreboardCard(for colorScheme: ColorScheme) -> Color {
        let traits = UITraitCollection(userInterfaceStyle: colorScheme == .dark ? .dark : .light)
        return Color(uiColor: UIColor(cardSurface).resolvedColor(with: traits))
    }

    static func dealerBadgeGradient(for colorScheme: ColorScheme) -> LinearGradient {
        switch colorScheme {
        case .dark:
            return LinearGradient(
                colors: [Color(red: 0.2, green: 0.45, blue: 0.28), Color(red: 0.12, green: 0.32, blue: 0.2)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        default:
            return LinearGradient(
                colors: [Color(red: 0.15, green: 0.55, blue: 0.25), Color(red: 0.08, green: 0.42, blue: 0.18)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    /// Secondary chips (New Game, Undo) on the felt. Light keeps the system-background chip with an accent
    /// label; dark uses a lifted felt green (~2.4:1 against the felt, plus a light border) with a white
    /// label (~6:1) because a near-black chip all but disappeared.
    static func feltChipFill(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(red: 0.20, green: 0.38, blue: 0.27) : Color(.systemBackground)
    }

    static func feltChipLabel(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.white : accent
    }

    static func feltChipBorder(for colorScheme: ColorScheme, increasedContrast: Bool) -> Color {
        if colorScheme == .dark { return Color.white.opacity(increasedContrast ? 1 : 0.45) }
        return accent.opacity(increasedContrast ? 1 : 0.35)
    }
}
