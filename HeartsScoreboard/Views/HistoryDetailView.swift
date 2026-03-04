import SwiftUI

struct HistoryDetailView: View {
    let completedGame: CompletedGame
    @Environment(\.colorScheme) private var colorScheme

    private var leadingPlayerIDs: Set<UUID> {
        let totals = completedGame.game.totals()
        guard let minTotal = totals.map(\.total).min() else { return [] }
        return Set(totals.filter { $0.total == minTotal }.map { $0.player.id })
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text(completedGame.finishedAt, format: .dateTime.month().day().year().hour().minute())
                    .font(.headline)
                    .foregroundStyle(Color.white)

                scoreboard
            }
            .padding()
        }
        .background(backgroundGradient)
        .navigationTitle("Game Summary")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var backgroundGradient: LinearGradient {
        switch colorScheme {
        case .light:
            return LinearGradient(
                colors: [
                    Color(red: 0.0, green: 0.55, blue: 0.25),
                    Color(red: 0.5, green: 0.95, blue: 0.55)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        case .dark:
            return LinearGradient(
                colors: [
                    Color(red: 0.03, green: 0.16, blue: 0.10),
                    Color(red: 0.02, green: 0.28, blue: 0.18)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        @unknown default:
            return LinearGradient(
                colors: [Color.green, Color.green.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private var scoreboard: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(
                            Color(red: 0.86, green: 1.0, blue: 0.91)
                                .opacity(colorScheme == .dark ? 0.9 : 0.85)
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(colorScheme == .dark ? 0.20 : 0.35), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.45 : 0.20), radius: 18, x: 0, y: 10)

            VStack(spacing: 12) {
                headerRows
                scoreRows
            }
            .padding(16)
        }
    }

    private var headerRows: some View {
        VStack(spacing: 8) {
            HStack(spacing: 0) {
                ForEach(completedGame.game.players) { player in
                    Text(player.name)
                        .font(.headline.weight(.semibold))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.white.opacity(colorScheme == .dark ? 0.10 : 0.26))
                        )
                        .frame(maxWidth: .infinity)
                }
            }

            HStack {
                ForEach(completedGame.game.players) { player in
                    let isLeader = leadingPlayerIDs.contains(player.id)
                    ZStack {
                        Capsule(style: .continuous)
                            .fill(
                                isLeader
                                ? Color.green.opacity(colorScheme == .dark ? 0.35 : 0.45)
                                : Color.white.opacity(colorScheme == .dark ? 0.08 : 0.20)
                            )
                            .frame(width: 68, height: 26)

                        Text("\(completedGame.game.totalPoints(for: player.id))")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(isLeader ? Color.primary : Color.primary.opacity(0.9))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private var scoreRows: some View {
        ScrollView {
            HStack(alignment: .top, spacing: 0) {
                ForEach(completedGame.game.players) { player in
                    VStack(spacing: 8) {
                        ForEach(Array(completedGame.game.hands.enumerated()), id: \.element.id) { index, hand in
                            let score = hand.pointsByPlayerID[player.id] ?? 0
                            let isEvenRow = index.isMultiple(of: 2)
                            let isMoon = completedGame.game.isMoonHand(hand, for: player.id)

                            Group {
                                if isMoon {
                                    Image(systemName: "moon.fill")
                                } else {
                                    Text("\(score)")
                                }
                            }
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(Color.primary)
                            .frame(width: 56, height: 26)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(
                                        (isEvenRow
                                         ? Color.white.opacity(colorScheme == .dark ? 0.18 : 0.30)
                                         : Color.white.opacity(colorScheme == .dark ? 0.26 : 0.42)
                                        )
                                    )
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .top)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}
