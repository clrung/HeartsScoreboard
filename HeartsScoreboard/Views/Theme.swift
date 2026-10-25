import SwiftUI

/// Felt-green brand palette shared by every screen. The accent itself lives in
/// `Assets.xcassets/AccentColor` (light #1F7A3B, dark #389E57) and is the app-wide tint.
enum Theme {
    static let accent = Color.accentColor

    /// Card-table background behind the game and history-detail screens.
    static func feltGradient(for colorScheme: ColorScheme) -> LinearGradient {
        switch colorScheme {
        case .dark:
            return LinearGradient(
                colors: [
                    Color(red: 0.03, green: 0.16, blue: 0.10),
                    Color(red: 0.02, green: 0.28, blue: 0.18)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        default:
            return LinearGradient(
                colors: [
                    Color(red: 0.0, green: 0.55, blue: 0.25),
                    Color(red: 0.5, green: 0.95, blue: 0.55)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    /// Fill for the scoreboard card that sits on the felt.
    static func scoreboardCard(for colorScheme: ColorScheme) -> Color {
        switch colorScheme {
        case .dark:
            return Color(red: 0.10, green: 0.18, blue: 0.14)
        default:
            return Color(red: 0.86, green: 1.0, blue: 0.91)
        }
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

    /// Leader highlight. Gold rather than green so it doesn't blend into the felt;
    /// always paired with a crown symbol so it's never conveyed by color alone.
    static let leader = Color(red: 0.96, green: 0.76, blue: 0.20)
}
