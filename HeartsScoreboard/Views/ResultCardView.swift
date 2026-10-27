import SwiftUI
import UIKit

/// Everything the shareable result card shows, derived from either a finished `CompletedGame`
/// (history) or the live `Standing`s (game-over card). Pure data so it can be unit tested.
struct ResultCardData: Equatable {
    struct Row: Equatable, Identifiable {
        let rank: Int
        let name: String
        let total: Int
        var isWinner: Bool { rank == 1 }
        var id: String { "\(rank)-\(name)" }
    }

    let date: Date
    /// Best to worst; tied players share a rank and keep seating order.
    let rows: [Row]
    /// Nil when the caller doesn't know it (hides the rounds line).
    let roundCount: Int?
    /// Running totals per player (seating order) for the sparkline; empty hides it.
    let series: [[Int]]

    init(standings: [Standing], date: Date, roundCount: Int? = nil, series: [[Int]] = []) {
        self.date = date
        self.rows = standings.map { Row(rank: $0.rank, name: $0.player.name, total: $0.total) }
        self.roundCount = roundCount
        self.series = series
    }

    init(completed: CompletedGame) {
        date = completed.finishedAt
        var rows: [Row] = []
        for (index, result) in completed.sortedResults.enumerated() {
            // Competition ranking: ties share the rank of the first of the tied group.
            let rank = (index > 0 && completed.sortedResults[index - 1].total == result.total)
                ? rows[index - 1].rank : index + 1
            rows.append(Row(rank: rank, name: result.name, total: result.total))
        }
        self.rows = rows
        roundCount = completed.roundCount
        series = completed.cumulativeSeries.map(\.points)
    }

    var winners: [Row] { rows.filter(\.isWinner) }
    var winnerNames: String { ListFormatter.localizedString(byJoining: winners.map(\.name)) }
    var winnerLabel: String { winners.count > 1 ? String(localized: "Winners") : String(localized: "Winner") }
    var winningScore: Int? { winners.first?.total }

    var roundsText: String? {
        guard let n = roundCount else { return nil }
        return String(localized: "\(n) rounds")  // plural rules: Localizable.stringsdict
    }

    var shareTitle: String {
        winners.isEmpty ? String(localized: "Hearts Scoreboard result")
            : "\(winnerNames) · " + String(localized: "Hearts Scoreboard")
    }
}

/// Fixed-width (360pt) card rendered to an image for sharing. Uses explicit light colors so the
/// image looks the same regardless of the system appearance.
struct ResultCardView: View {
    static let width: CGFloat = 360
    let data: ResultCardData

    private static let ink = Color(red: 0.07, green: 0.12, blue: 0.09)
    private static let green = Color(red: 0.10, green: 0.45, blue: 0.20)
    private static let lines: [Color] = [
        Color(red: 0.12, green: 0.45, blue: 0.85), Color(red: 0.85, green: 0.25, blue: 0.25),
        Color(red: 0.90, green: 0.55, blue: 0.10), Color(red: 0.55, green: 0.30, blue: 0.75),
        Color(red: 0.10, green: 0.60, blue: 0.55), Color(red: 0.45, green: 0.45, blue: 0.45)
    ]

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: "suit.heart.fill").foregroundStyle(Color(red: 0.80, green: 0.12, blue: 0.15))
                Text("Hearts Scoreboard").font(.headline.weight(.bold))
                Spacer()
                Text(data.date, format: .dateTime.month(.abbreviated).day().year())
                    .font(.footnote)
                    .foregroundStyle(Self.ink.opacity(0.6))
            }
            .foregroundStyle(Self.ink)

            VStack(spacing: 4) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Theme.leader)
                Text(data.winnerLabel)
                    .font(.caption.weight(.semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(Self.ink.opacity(0.6))
                Text(data.winnerNames)
                    .font(.system(.title, design: .rounded).weight(.bold))
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.6)
                    .foregroundStyle(Self.ink)
                if let score = data.winningScore {
                    Text("\(score) points")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(Self.ink.opacity(0.6))
                }
            }

            VStack(spacing: 6) {
                ForEach(data.rows) { row in
                    HStack(spacing: 10) {
                        Text("\(row.rank)")
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                            .foregroundStyle(row.isWinner ? Color.black : Self.ink.opacity(0.6))
                            .frame(width: 24, height: 24)
                            .background(Circle().fill(row.isWinner ? Theme.leader : Color.clear))
                        Text(row.name)
                            .font(.body.weight(.medium))
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("\(row.total)")
                            .font(.title3.weight(.semibold).monospacedDigit())
                    }
                    .foregroundStyle(Self.ink)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(row.isWinner ? Theme.leader.opacity(0.25) : Self.ink.opacity(0.06))
                    )
                }
            }

            if data.roundsText != nil || hasSparkline {
                HStack(spacing: 12) {
                    if let text = data.roundsText {
                        Text(text)
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(Self.ink.opacity(0.6))
                    }
                    if hasSparkline {
                        Sparkline(series: data.series, winnerIndices: winnerSeriesIndices)
                            .frame(height: 36)
                    }
                }
            }
        }
        .padding(18)
        .frame(width: Self.width)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color.white)
        )
        .padding(12)
        .background(Theme.feltGradient(for: .light))
        .environment(\.colorScheme, .light)
        .environment(\.dynamicTypeSize, .large)
    }

    private var hasSparkline: Bool { (data.series.first?.count ?? 0) >= 2 }

    /// Series are in seating order while rows are ranked; the sparkline highlights the winners' lines
    /// by matching final totals (a tied total highlights every tied line, which is what we want).
    private var winnerSeriesIndices: Set<Int> {
        guard let best = data.winningScore else { return [] }
        return Set(data.series.indices.filter { data.series[$0].last == best })
    }

    private struct Sparkline: View {
        let series: [[Int]]
        let winnerIndices: Set<Int>

        var body: some View {
            let all = series.flatMap { $0 }
            let lo = all.min() ?? 0, hi = all.max() ?? 1
            let span = max(1, hi - lo)
            GeometryReader { geo in
                ForEach(Array(series.enumerated()), id: \.offset) { index, points in
                    Path { path in
                        for (i, value) in points.enumerated() {
                            let x = geo.size.width * CGFloat(i) / CGFloat(max(1, points.count - 1))
                            let y = geo.size.height * (1 - CGFloat(value - lo) / CGFloat(span))
                            i == 0 ? path.move(to: CGPoint(x: x, y: y)) : path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                    .stroke(
                        ResultCardView.lines[index % ResultCardView.lines.count]
                            .opacity(winnerIndices.contains(index) ? 1 : 0.55),
                        style: StrokeStyle(lineWidth: winnerIndices.contains(index) ? 2.5 : 1.5,
                                           lineCap: .round, lineJoin: .round)
                    )
                }
            }
        }
    }
}

/// Renders the card to a 3x bitmap.
enum ResultCardRenderer {
    @MainActor
    static func image(for data: ResultCardData) -> UIImage? {
        let renderer = ImageRenderer(content: ResultCardView(data: data))
        renderer.scale = 3
        return renderer.uiImage
    }
}

/// Share button: renders the card once (re-rendering if the data changes) and hands it to `ShareLink`.
struct ResultShareButton: View {
    let data: ResultCardData
    @State private var image: Image?

    var body: some View {
        Group {
            if let image {
                ShareLink(item: image, preview: SharePreview(data.shareTitle, image: image)) {
                    Image(systemName: "square.and.arrow.up")
                }
            } else {
                Image(systemName: "square.and.arrow.up").opacity(0.3)
            }
        }
        .accessibilityLabel(Text("Share result"))
        .task(id: data) {
            if let ui = ResultCardRenderer.image(for: data) { image = Image(uiImage: ui) }
        }
    }
}
