import SwiftUI

/// The end-of-game card: trophy, winner name(s), ranked standings, Rematch / View history.
/// Used as an overlay on compact width (with a close button) and as the right pane at regular width.
struct GameOverView: View {
    let standings: [Standing]
    let onRematch: () -> Void
    let onViewHistory: () -> Void
    /// Nil when the card can't be dismissed (the split layout shows it in a pane next to the scoreboard).
    var onClose: (() -> Void)?

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .headline) private var rankBadgeSize: CGFloat = 28

    /// Same deep green as the Next Round button (white text is ~5.9:1 on it).
    private static let buttonGreen = Color(red: 0.10, green: 0.45, blue: 0.20)

    private var winners: [Standing] { standings.filter(\.isWinner) }

    private var winnerNames: String {
        ListFormatter.localizedString(byJoining: winners.map(\.player.name))
    }

    var body: some View {
        // Buttons stay pinned below the scrolling standings, except at accessibility text sizes where
        // pinned buttons would squeeze the standings to nothing: there everything scrolls together.
        let pinButtons = !dynamicTypeSize.isAccessibilitySize
        return VStack(spacing: 16) {
            ScrollView {
                VStack(spacing: 16) {
                    hero
                    standingsList
                    if !pinButtons { buttons }
                }
                .padding(.top, 8)
            }
            .scrollBounceBehavior(.basedOnSize)

            if pinButtons { buttons }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .modifier(CloseOverlay(onClose: onClose))
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.5 : 0.25), radius: 18, x: 0, y: 10)
        .accessibilityElement(children: .contain)
    }

    private var buttons: some View {
        VStack(spacing: 10) {
                Button(action: onRematch) {
                    Label("Rematch", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Self.buttonGreen)
                .accessibilityIdentifier("gameOver.rematch")

                Button(action: onViewHistory) {
                    Label("View history", systemImage: "clock.arrow.circlepath")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("gameOver.history")
            }
        .controlSize(.large)
    }

    private var hero: some View {
        VStack(spacing: 6) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 48))
                .foregroundStyle(Theme.leader)
                .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
                .accessibilityHidden(true)
            Text(winners.count > 1 ? "Winners" : "Winner")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text(winnerNames)
                .font(.largeTitle.weight(.bold))
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.6)
                .accessibilityAddTraits(.isHeader)
            if let score = winners.first?.total {
                Text("\(score) points")
                    .font(.title3.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var standingsList: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Final standings")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .accessibilityAddTraits(.isHeader)
            ForEach(standings) { standing in
                HStack(spacing: 12) {
                    Text("\(standing.rank)")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(standing.isWinner ? Color.black : .secondary)
                        .frame(width: rankBadgeSize, height: rankBadgeSize)
                        .background(Circle().fill(standing.isWinner ? Theme.leader : Color.clear))
                    Text(standing.player.name)
                        .font(.headline)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("\(standing.total)")
                        .font(.title3.weight(.semibold).monospacedDigit())
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(standing.isWinner ? Theme.leader.opacity(0.22) : Color.primary.opacity(0.06))
                )
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(String(
                    format: String(localized: "%d. %@, %d points"),
                    standing.rank, standing.player.name, standing.total
                )))
            }
        }
    }
}

private struct CloseOverlay: ViewModifier {
    let onClose: (() -> Void)?

    func body(content: Content) -> some View {
        content.overlay(alignment: .topTrailing) {
            if let onClose {
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel(Text("Close"))
                .accessibilityIdentifier("gameOver.close")
                .padding(4)
            }
        }
    }
}

/// Lightweight confetti: a fixed set of pieces falling over ~5 seconds, drawn in one `Canvas`.
/// Callers must not show it when Reduce Motion is on; this view also checks, as a backstop.
struct ConfettiView: View {
    private static let duration: TimeInterval = 5
    private static let colors: [Color] = [
        Theme.leader, .red, .green, .blue, .orange, .pink, .mint, .purple
    ]

    private struct Piece {
        let x: Double        // 0...1 across the width
        let delay: Double    // seconds
        let speed: Double    // points/second
        let sway: Double
        let spin: Double
        let size: Double
        let color: Color
    }

    private let pieces: [Piece]
    /// Fixed start, so tests can render a known frame.
    private let start: Date
    @State private var finished = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(start: Date = Date()) {
        self.start = start
        var rng = SeededGenerator(seed: 0xC0FFEE)
        pieces = (0..<80).map { _ in
            Piece(
                x: .random(in: 0...1, using: &rng),
                delay: .random(in: 0...1.2, using: &rng),
                speed: .random(in: 220...420, using: &rng),
                sway: .random(in: 8...28, using: &rng),
                spin: .random(in: -6...6, using: &rng),
                size: .random(in: 7...12, using: &rng),
                color: Self.colors.randomElement(using: &rng) ?? .red
            )
        }
    }

    var body: some View {
        Group {
            if !reduceMotion && !finished {
                TimelineView(.animation) { timeline in
                    Canvas { context, size in
                        let t = timeline.date.timeIntervalSince(start)
                        for piece in pieces {
                            let age = t - piece.delay
                            guard age >= 0 else { continue }
                            let y = -20 + age * piece.speed
                            guard y < size.height + 20 else { continue }
                            let x = piece.x * size.width + sin(age * 3 + piece.x * 10) * piece.sway
                            var layer = context
                            layer.translateBy(x: x, y: y)
                            layer.rotate(by: .radians(age * piece.spin))
                            // Fade out over the last second so it ends softly.
                            layer.opacity = min(1, max(0, Self.duration - t))
                            layer.fill(
                                Path(CGRect(x: -piece.size / 2, y: -piece.size / 4, width: piece.size, height: piece.size / 2)),
                                with: .color(piece.color)
                            )
                        }
                    }
                }
                .task {
                    let remaining = max(0, Self.duration - Date().timeIntervalSince(start))
                    try? await Task.sleep(for: .seconds(remaining))
                    finished = true
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Deterministic generator so confetti looks the same every run (and in snapshots).
private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
