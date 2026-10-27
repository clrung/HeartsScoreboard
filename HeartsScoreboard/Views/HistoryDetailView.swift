import SwiftUI
import Charts

struct HistoryDetailView: View {
    let completedGame: CompletedGame
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private var leadingPlayerIDs: Set<UUID> {
        let totals = completedGame.game.totals()
        guard let minTotal = totals.map(\.total).min() else { return [] }
        return Set(totals.filter { $0.total == minTotal }.map { $0.player.id })
    }

    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        ZStack {
            Theme.feltGradient(for: colorScheme, contrast: contrast).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    summaryHeader
                    statsRow
                    chartCard
                    scoreboard
                }
                .frame(maxWidth: 900)
                .frame(maxWidth: .infinity)
                .padding(.horizontal)
                .padding(.vertical, 16)
            }
        }
        .navigationTitle("Game Summary")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ResultShareButton(data: ResultCardData(completed: completedGame))
                    .accessibilityIdentifier("historyDetail.share")
            }
        }
    }

    // MARK: Summary

    private var summaryHeader: some View {
        VStack(spacing: 4) {
            Text(completedGame.finishedAt, format: .dateTime.month().day().year().hour().minute())
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("historyDetail.date")
            HStack(spacing: 8) {
                Image(systemName: "trophy.fill")
                    .foregroundStyle(Theme.leader)
                    .accessibilityHidden(true)
                Text(completedGame.heroText)
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
            }
            .accessibilityElement(children: .combine)
            Text(completedGame.ruleSummary)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var statsRow: some View {
        let g = completedGame
        var items: [(String, String)] = [
            (String(localized: "Rounds"), "\(g.roundCount)"),
            (String(localized: "Moons"), "\(g.moonCount)")
        ]
        if g.settings.tenOfDiamondsMinus10 {
            items.append((String(localized: "10♦ taken"), "\(g.tenOfDiamondsCount)"))
        }
        if let big = g.biggestHand {
            items.append((String(localized: "Biggest hand"), "\(big.points)"))
        }
        return HStack(spacing: 8) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                VStack(spacing: 2) {
                    Text(item.1)
                        .font(.title3.weight(.bold))
                        .monospacedDigit()
                    Text(item.0)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .padding(.horizontal, 4)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(cardFill))
                .accessibilityElement(children: .combine)
            }
        }
    }

    private var cardFill: Color {
        reduceTransparency
            ? Theme.scoreboardCard(for: colorScheme)
            : Theme.scoreboardCard(for: colorScheme).opacity(colorScheme == .dark ? 0.9 : 0.85)
    }

    private var chartCard: some View {
        let series = completedGame.cumulativeSeries
        let ending = completedGame.settings.endingScore
        let allPoints = series.flatMap(\.points)
        let lo = min(0, allPoints.min() ?? 0)
        let hi = max(ending, allPoints.max() ?? 0)
        return VStack(alignment: .leading, spacing: 8) {
            Text("Score by round")
                .font(.headline)
            Chart {
                ForEach(series) { s in
                    ForEach(Array(s.points.enumerated()), id: \.offset) { round, total in
                        LineMark(
                            x: .value("Round", round),
                            y: .value("Score", total),
                            series: .value("Player", s.id.uuidString)
                        )
                        .foregroundStyle(by: .value("Name", s.name))
                        .interpolationMethod(.monotone)
                    }
                }
                RuleMark(y: .value("Ending score", ending))
                    .foregroundStyle(Color.red.opacity(0.8))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    .annotation(position: .top, alignment: .leading) {
                        Text("\(ending)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.red)
                    }
            }
            // Numeric time axis: always read rounds 1→N left to right, with y labels on the left, in RTL too.
            .environment(\.layoutDirection, DirectionalUI.chartLayoutDirection)
            .chartYScale(domain: lo...(hi + max(4, (hi - lo) / 10)))
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 6)) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let r = value.as(Int.self) { Text("\(r)") }
                    }
                }
            }
            .chartXAxisLabel(String(localized: "Round"), alignment: .center)
            .chartLegend(position: .bottom, alignment: .center, spacing: 8)
            .frame(height: sizeClass == .regular ? 280 : 200)
            .accessibilityLabel(Text("Score by round"))
            .accessibilityValue(Text(chartAccessibilitySummary))
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(cardFill))
    }

    private var chartAccessibilitySummary: String {
        completedGame.sortedResults.map { "\($0.name) \($0.total)" }.joined(separator: ", ")
    }

    private var scoreboard: some View {
        VStack(spacing: 12) {
            headerRows
            HStack(alignment: .top, spacing: 0) {
                ForEach(completedGame.game.players) { player in
                    ScoreColumnView(
                        game: completedGame.game,
                        playerID: player.id,
                        colorScheme: colorScheme,
                        flexible: sizeClass == .regular
                    )
                    .frame(maxWidth: .infinity, alignment: .top)
                }
            }
        }
        .padding(6)
        .padding(.bottom, 4)
        .frame(maxWidth: .infinity)
        .background(
            FeltCardSurface(cornerRadius: 24, colorScheme: colorScheme)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(colorScheme == .dark ? 0.20 : 0.35), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.45 : 0.20), radius: 18, x: 0, y: 10)
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
}

// MARK: - Helper views (break up type-checker complexity)

private struct ScoreColumnView: View {
    let game: HeartsGame
    let playerID: UUID
    let colorScheme: ColorScheme
    var flexible = false

    var body: some View {
        VStack(spacing: 8) {
            ForEach(Array(game.hands.enumerated()), id: \.element.id) { index, hand in
                ScoreCellView(
                    round: index + 1,
                    playerName: game.players.first { $0.id == playerID }?.name ?? "",
                    score: hand.pointsByPlayerID[playerID] ?? 0,
                    isMoon: game.isMoonHand(hand, for: playerID),
                    hasTenOfDiamonds: hand.tenOfDiamondsPlayerID == playerID,
                    moonBonus: game.moonCellTenOfDiamondsBonus(hand, for: playerID),
                    isEvenRow: index.isMultiple(of: 2),
                    colorScheme: colorScheme,
                    flexible: flexible
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
    let moonBonus: Int?
    let isEvenRow: Bool
    let colorScheme: ColorScheme
    var flexible = false

    private var accessibilityText: String {
        var text = isMoon
            ? String(format: String(localized: "Round %d, %@: shot the moon"), round, playerName)
            : String(format: String(localized: "Round %d, %@: %d points"), round, playerName, score)
        if hasTenOfDiamonds { text += String(localized: ", took the 10 of diamonds") }
        return text
    }

    var body: some View {
        ScoreCellContent(score: score, isMoon: isMoon, moonBonus: moonBonus)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .modifier(HistoryCellFrame(hasTenOfDiamonds: hasTenOfDiamonds, flexible: flexible))
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

/// History-detail cell sizing: like `ScoreCellFrame` (56pt cap) on compact width, but cells grow with
/// their column (up to 140pt) at regular width so wide screens don't leave tiny cells in huge columns.
private struct HistoryCellFrame: ViewModifier {
    let hasTenOfDiamonds: Bool
    let flexible: Bool
    @ScaledMetric(relativeTo: .footnote) private var cellHeight: CGFloat = 26
    @ScaledMetric(relativeTo: .footnote) private var compactWidth: CGFloat = 56
    @ScaledMetric(relativeTo: .caption2) private var diamondSize: CGFloat = 9

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, hasTenOfDiamonds ? diamondSize * 0.9 : 0)
            .frame(maxWidth: flexible ? 140 : compactWidth, minHeight: cellHeight)
            .overlay(alignment: .topTrailing) {
                if hasTenOfDiamonds {
                    Text("♦")
                        .font(.system(size: diamondSize, weight: .semibold))
                        .foregroundStyle(Color.red)
                        .padding(.trailing, 2)
                }
            }
    }
}
