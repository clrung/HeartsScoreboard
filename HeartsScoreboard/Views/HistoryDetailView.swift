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
        ZStack {
            Theme.feltGradient(for: colorScheme).ignoresSafeArea()

            VStack(spacing: 16) {
                Text(completedGame.finishedAt, format: .dateTime.month().day().year().hour().minute())
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .accessibilityIdentifier("historyDetail.date")

                scoreboard

                Spacer(minLength: 0)
            }
            .padding(.horizontal)
            .padding(.vertical, 16)
        }
        .navigationTitle("Game Summary")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var scoreboard: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(.ultraThinMaterial)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        Theme.scoreboardCard(for: colorScheme)
                            .opacity(colorScheme == .dark ? 0.9 : 0.85)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(colorScheme == .dark ? 0.20 : 0.35), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.45 : 0.20), radius: 18, x: 0, y: 10)
            .overlay(alignment: .top) {
                scoreboardContent
            }
            .frame(maxHeight: .infinity, alignment: .top)
    }

    private var headerRows: some View {
        VStack(spacing: 8) {
            headerNameRow
            headerTotalsRow
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(colorScheme == .dark ? 0.14 : 0.06))
        )
    }

    private var headerNameRow: some View {
        HStack(spacing: 0) {
            ForEach(completedGame.game.players) { player in
                Text(player.name)
                    .font(.headline.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .accessibilityAddTraits(.isHeader)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.white.opacity(colorScheme == .dark ? 0.10 : 0.26))
                    )
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var headerTotalsRow: some View {
        HStack {
            ForEach(completedGame.game.players) { player in
                PlayerTotalBadge(
                    total: completedGame.game.totalPoints(for: player.id),
                    isLeader: leadingPlayerIDs.contains(player.id),
                    colorScheme: colorScheme
                )
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var scoreboardContent: some View {
        VStack(spacing: 12) {
            headerRows
            scoresScroll
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.vertical, 6)
        .padding(.horizontal, 6)
    }

    private var scoresScroll: some View {
        ScrollView {
            HStack(alignment: .top, spacing: 0) {
                ForEach(completedGame.game.players) { player in
                    ScoreColumnView(
                        game: completedGame.game,
                        playerID: player.id,
                        colorScheme: colorScheme
                    )
                    .frame(maxWidth: .infinity, alignment: .top)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 8)
        }
        .frame(maxHeight: .infinity)
        .scrollIndicators(.visible)
    }
}

// MARK: - Helper views (break up type-checker complexity)

private struct ScoreColumnView: View {
    let game: HeartsGame
    let playerID: UUID
    let colorScheme: ColorScheme

    var body: some View {
        VStack(spacing: 8) {
            ForEach(Array(game.hands.enumerated()), id: \.element.id) { index, hand in
                ScoreCellView(
                    round: index + 1,
                    playerName: game.players.first { $0.id == playerID }?.name ?? "",
                    score: hand.pointsByPlayerID[playerID] ?? 0,
                    isMoon: game.isMoonHand(hand, for: playerID),
                    hasTenOfDiamonds: hand.tenOfDiamondsPlayerID == playerID,
                    isEvenRow: index.isMultiple(of: 2),
                    colorScheme: colorScheme
                )
            }
        }
    }
}

private struct ScoreCellView: View {
    let round: Int
    let playerName: String
    let score: Int
    let isMoon: Bool
    let hasTenOfDiamonds: Bool
    let isEvenRow: Bool
    let colorScheme: ColorScheme

    private var accessibilityText: String {
        var text = isMoon
            ? String(format: String(localized: "Round %d, %@: shot the moon"), round, playerName)
            : String(format: String(localized: "Round %d, %@: %d points"), round, playerName, score)
        if hasTenOfDiamonds { text += String(localized: ", took the 10 of diamonds") }
        return text
    }

    var body: some View {
        Group {
            if isMoon {
                Image(systemName: "moon.fill")
            } else {
                Text("\(score)")
            }
        }
        .font(.footnote.weight(.medium))
        .foregroundStyle(Color.primary)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .frame(width: 56, height: 26)
        .overlay(alignment: .topTrailing) {
            if hasTenOfDiamonds {
                Text("♦")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Color.red)
                    .padding(.trailing, 4)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    isEvenRow
                    ? Color.white.opacity(colorScheme == .dark ? 0.18 : 0.30)
                    : Color.white.opacity(colorScheme == .dark ? 0.26 : 0.42)
                )
        )
    }
}
