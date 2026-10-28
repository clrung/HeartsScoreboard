import SwiftUI
import Charts
import UIKit

struct HistoryDetailView: View {
    let completedGame: CompletedGame
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        ZStack {
            Theme.feltGradient(for: colorScheme, contrast: contrast).ignoresSafeArea()
            ScrollView {
                HistoryDetailContent(completedGame: completedGame)
                    .frame(maxWidth: 900)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal)
                    .padding(.vertical, 16)
            }
        }
        .environment(\.colorScheme, colorScheme)
        .navigationTitle("Game Summary")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HistoryShareButton(completedGame: completedGame)
                    .accessibilityIdentifier("historyDetail.share")
            }
        }
    }
}

/// Shared presentation for the on-screen history detail and its full-size share image.
struct HistoryDetailContent: View {
    let completedGame: CompletedGame
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var leadingPlayerIDs: Set<UUID> {
        let totals = completedGame.game.totals()
        guard let minTotal = totals.map(\.total).min() else { return [] }
        return Set(totals.filter { $0.total == minTotal }.map { $0.player.id })
    }

    var body: some View {
        VStack(spacing: 16) {
            summaryHeader
            statsRow
            chartCard
            scoreboard
        }
        .environment(\.colorScheme, colorScheme)
    }

    // MARK: Summary

    private var summaryHeader: some View {
        VStack(spacing: 4) {
            Text(completedGame.finishedAt, format: .dateTime.month().day().year().hour().minute())
                .font(.subheadline)
                .foregroundStyle(Color.white.opacity(0.78)) // on the felt, never the adaptive secondary (dark gray in light mode)
                .accessibilityIdentifier("historyDetail.date")
            HStack(spacing: 8) {
                Image(systemName: "trophy.fill")
                    .foregroundStyle(Theme.leader)
                    .accessibilityHidden(true)
                Text(completedGame.heroText)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Color.white)
                    .multilineTextAlignment(.center)
            }
            .accessibilityElement(children: .combine)
            Text(completedGame.ruleSummary)
                .font(.footnote)
                .foregroundStyle(Color.white.opacity(0.78))
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

    /// Same family as the main scoreboard card: card surface, inset standings header, zebra round rows.
    private var scoreboard: some View {
        let shape = RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
        let shadow = Theme.Elevation.card(for: colorScheme)
        let game = completedGame.game
        return VStack(spacing: 0) {
            VStack(spacing: Theme.Spacing.s) {
                headerNameRow
                headerTotalsRow
            }
            .padding(.horizontal, Theme.Spacing.s)
            .padding(.vertical, Theme.Spacing.m)
            .background(Theme.cardInset)

            VStack(spacing: 0) {
                ForEach(Array(game.hands.enumerated()), id: \.element.id) { index, hand in
                    HStack(spacing: 0) {
                        ForEach(game.players) { player in
                            ScoreCellView(
                                round: index + 1,
                                playerName: player.name,
                                score: hand.pointsByPlayerID[player.id] ?? 0,
                                isMoon: game.isMoonHand(hand, for: player.id),
                                hasTenOfDiamonds: hand.tenOfDiamondsPlayerID == player.id,
                                moonBonus: game.moonCellTenOfDiamondsBonus(hand, for: player.id)
                            )
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.s)
                    .background(index.isMultiple(of: 2) ? Color.clear : Theme.rowZebra)
                }
            }
            .padding(.vertical, Theme.Spacing.xs)
        }
        .frame(maxWidth: .infinity)
        .background(Theme.cardSurface)
        .clipShape(shape)
        .overlay(shape.strokeBorder(Color.primary.opacity(colorScheme == .dark ? 0.14 : 0.07), lineWidth: 1))
        .shadow(color: shadow.color, radius: shadow.radius, x: 0, y: shadow.y)
    }

    private var headerNameRow: some View {
        HStack(spacing: 0) {
            ForEach(completedGame.game.players) { player in
                Text(player.name)
                    .font(.headline.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .minimumScaleFactor(0.7)
                    .accessibilityAddTraits(.isHeader)
                    .padding(.horizontal, 4)
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


private struct ScoreCellView: View {
    let round: Int
    let playerName: String
    let score: Int
    let isMoon: Bool
    let hasTenOfDiamonds: Bool
    let moonBonus: Int?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var tookAll: Bool { score == 26 && !isMoon }

    private var accessibilityText: String {
        var text = isMoon
            ? String(format: String(localized: "Round %d, %@: shot the moon"), round, playerName)
            : String(format: String(localized: "Round %d, %@: %d points"), round, playerName, score)
        if hasTenOfDiamonds { text += String(localized: ", took the 10 of diamonds") }
        return text
    }

    var body: some View {
        ScoreCellContent(score: score, isMoon: isMoon, moonBonus: moonBonus, emphasize: tookAll)
            .foregroundStyle(tookAll ? Theme.allPointsText : (score == 0 && !isMoon ? Color.secondary : Color.primary))
            .padding(.horizontal, hasTenOfDiamonds ? 10 : 0)
            .overlay(alignment: .topTrailing) {
                if hasTenOfDiamonds {
                    Text("♦")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.red)
                        .offset(y: -3)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 32)
            .background {
                if tookAll {
                    RoundedRectangle(cornerRadius: Theme.Radius.cell, style: .continuous)
                        .fill(Theme.allPointsFill)
                        .padding(3)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityText)
    }
}

/// Full history-detail image with a fixed wide canvas and enough height for every round.
private struct HistoryDetailShareImage: View {
    let completedGame: CompletedGame

    var body: some View {
        HistoryDetailContent(completedGame: completedGame)
            .frame(width: HistoryShareRenderer.contentWidth(playerCount: completedGame.game.players.count))
            .padding(24)
            .background(Theme.feltGradient(for: .light))
            .fixedSize(horizontal: false, vertical: true)
            .environment(\.colorScheme, .light)
                .environment(\.horizontalSizeClass, .regular)
            .environment(\.dynamicTypeSize, .large)
    }
}

struct HistoryShareButton: View {
    let completedGame: CompletedGame
    @State private var shareFile: NamedPNGFile?
    @State private var preview: Image?

    var body: some View {
        Group {
            if let shareFile, let preview {
                ShareLink(item: shareFile, preview: SharePreview(ResultCardData(completed: completedGame).shareTitle, image: preview)) {
                    Image(systemName: "square.and.arrow.up")
                }
            } else {
                Image(systemName: "square.and.arrow.up").opacity(0.3)
            }
        }
        .accessibilityLabel(Text("Share result"))
        .task(id: completedGame) {
            guard let image = await HistoryShareRenderer.image(for: completedGame),
                  let file = try? NamedPNGFile.make(image: image, date: completedGame.finishedAt) else { return }
            shareFile = file
            preview = Image(uiImage: image)
        }
    }
}

enum HistoryShareRenderer {
    static func contentWidth(playerCount: Int) -> CGFloat {
        max(480, CGFloat(playerCount) * 110)
    }

    @MainActor
    static func image(for game: CompletedGame) async -> UIImage? {
        let content = HistoryDetailShareImage(completedGame: game)
        let measurement = ImageRenderer(content: content)
        var canvasSize = CGSize.zero
        measurement.render { size, _ in canvasSize = size }
        guard canvasSize.width > 0, canvasSize.height > 0 else { return nil }
        let pixelBudget: CGFloat = 32_000_000
        let scale = min(2, sqrt(pixelBudget / (canvasSize.width * canvasSize.height)))
        let renderer = ImageRenderer(content: content)
        renderer.scale = scale
        return renderer.uiImage
    }
}
