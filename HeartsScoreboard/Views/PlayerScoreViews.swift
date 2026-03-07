import SwiftUI

// MARK: - Player total badge (shared by GameView, HistoryDetailView, RoundInputView)

/// Displays a player's total score in the same capsule style used on the game scoreboard.
/// Use for current/total score next to names or in score rows.
struct PlayerTotalBadge: View {
    let total: Int
    let isLeader: Bool
    let colorScheme: ColorScheme

    var body: some View {
        ZStack {
            Capsule(style: .continuous)
                .fill(
                    isLeader
                    ? Color.green.opacity(0.5)
                    : Color.gray.opacity(0.5)
                )
                .frame(width: 36, height: 26)

            Text("\(total)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isLeader ? Color.primary : Color.primary.opacity(0.9))
        }
    }
}

// MARK: - Player name + total row (for RoundInputView and any single-row name+score display)

/// Displays a player name with their current total in the same badge style as the game scoreboard.
struct PlayerNameWithTotalView: View {
    let name: String
    let total: Int
    let isLeader: Bool
    let colorScheme: ColorScheme

    var body: some View {
        HStack(spacing: 8) {
            Text(name)
                .font(.headline.weight(.semibold))
                .lineLimit(1)
                .truncationMode(.tail)

            PlayerTotalBadge(total: total, isLeader: isLeader, colorScheme: colorScheme)
        }
    }
}
