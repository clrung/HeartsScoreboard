import SwiftUI

// MARK: - Player total badge (shared by GameView, HistoryDetailView, RoundInputView)

/// Direction-sensitive UI helpers (RTL audit 2026-10-26), kept as pure functions so tests can cover them.
enum DirectionalUI {
    /// Mirrors in RTL (unlike the fixed-direction `chevron.left`).
    static let backSymbol = "chevron.backward"
    static let nextRoundSymbol = "arrow.forward.circle.fill"
    /// The history chart is numeric: always left to right.
    static let chartLayoutDirection: LayoutDirection = .leftToRight
    /// The points stepper always reads "− N +" (minus left, plus right), also in RTL.
    static let stepperLayoutDirection: LayoutDirection = .leftToRight

    /// "Quick-add button: +5" with the "+5" isolated as an LTR run so RTL bidi keeps the plus first.
    static func quickAddTitle(points: Int) -> String {
        let title = String(format: String(localized: "Quick-add button: +%d"), points)
        let token = "+\(points)"
        return title.replacingOccurrences(of: token, with: "\u{2066}\(token)\u{2069}")
    }
}

extension View {
    /// Pins a −/+ points cluster to left-to-right so it reads "− N +" in every language.
    func pointsStepperLayout() -> some View {
        environment(\.layoutDirection, DirectionalUI.stepperLayoutDirection)
    }
}

/// Displays a player's total score in a capsule. A leader gets a crown (so it isn't color-only),
/// and the optional `progress` / `pointsToGo` add a progress bar and caption under the total.
/// Existing call sites that pass only `total`, `isLeader` and `colorScheme` keep working.
struct PlayerTotalBadge: View {
    let total: Int
    let isLeader: Bool
    let colorScheme: ColorScheme
    /// Fraction (0...1) of the ending score; nil hides the bar.
    var progress: Double? = nil
    /// Points left before the game ends; nil hides the caption.
    var pointsToGo: Int? = nil
    /// When true (default) the badge reserves headroom above the capsule for the leader's crown, which
    /// makes its layout box taller than the capsule and puts the capsule below the box's center. Rows that
    /// center the badge against sibling content pass false (symmetric padding, so box center == capsule
    /// center) and must leave room for the crown overlay themselves.
    var reservesCrownSpace: Bool = true

    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .callout) private var minWidth: CGFloat = 40
    @ScaledMetric(relativeTo: .callout) private var capsuleHeight: CGFloat = 28
    @ScaledMetric(relativeTo: .callout) private var crownSize: CGFloat = 12

    private var isIncreasedContrast: Bool { contrast == .increased }

    private var leaderFill: Color { Color(red: 0.10, green: 0.16, blue: 0.12) }

    private var barColor: Color {
        guard let progress else { return Theme.accent }
        if progress >= 0.9 { return Color(red: 0.80, green: 0.12, blue: 0.12) }
        if progress >= 0.75 { return Color(red: 0.90, green: 0.55, blue: 0.0) }
        return Theme.accent
    }

    var body: some View {
        VStack(spacing: 3) {
            totalCapsule
            if let progress {
                progressBar(progress)
            }
            if let pointsToGo {
                Text(String(format: String(localized: "%d to go"), pointsToGo))
                    .font(.caption2.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(Color.primary.opacity(isIncreasedContrast ? 1 : 0.8))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.85), value: total)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(total)"))
        .accessibilityValue(Text(accessibilityValueText))
    }

    private var accessibilityValueText: String {
        var parts: [String] = []
        if isLeader { parts.append(String(localized: "Leading")) }
        if let pointsToGo { parts.append(String(format: String(localized: "%d to go"), pointsToGo)) }
        return parts.joined(separator: ", ")
    }

    private var totalCapsule: some View {
        Text("\(total)")
            .font(.callout.weight(.bold))
            .monospacedDigit()
            .contentTransition(.numericText(value: Double(total)))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .foregroundStyle(isLeader ? Color.white : Color.primary)
            .padding(.horizontal, 8)
            .frame(minWidth: minWidth, minHeight: capsuleHeight)
            .background {
                Capsule(style: .continuous)
                    .fill(isLeader ? leaderFill : Color.gray.opacity(isIncreasedContrast ? 0.45 : 0.25))
            }
            .overlay {
                if isLeader {
                    Capsule(style: .continuous).strokeBorder(Theme.leader, lineWidth: isIncreasedContrast ? 2 : 1.5)
                } else if isIncreasedContrast {
                    Capsule(style: .continuous).strokeBorder(Color.primary.opacity(0.6), lineWidth: 1)
                }
            }
            .overlay(alignment: .topTrailing) {
                if isLeader {
                    Image(systemName: "crown.fill")
                        .font(.system(size: crownSize, weight: .bold))
                        .foregroundStyle(Theme.leader)
                        .padding(2.5)
                        .background(Circle().fill(leaderFill))
                        // Sits on the capsule's top-trailing corner (SwiftUI mirrors `.offset(x:)` in RTL, verified; see
                        // DirectionalUITests.testCrownOverhangMirrorsInRTL), above the digits (scales with the crown).
                        .offset(x: crownSize * 0.6, y: -crownSize * 0.95)
                        .accessibilityHidden(true)
                }
            }
            // Room for the crown (its top sits ~0.95*crownSize above the capsule); constant so a leader
            // doesn't shift the row, and scales with Dynamic Type via crownSize.
            .padding(.top, reservesCrownSpace ? max(4, crownSize * 0.95 + 2) : 4)
            .padding(.bottom, 4)
    }

    private func progressBar(_ progress: Double) -> some View {
        Capsule()
            .fill(Color.primary.opacity(isIncreasedContrast ? 0.35 : 0.15))
            .frame(maxWidth: 56)
            .frame(height: isIncreasedContrast ? 6 : 4)
            .overlay(alignment: .leading) {
                GeometryReader { geo in
                    Capsule()
                        .fill(barColor)
                        .frame(width: geo.size.width * min(1, max(0, progress)))
                }
            }
            .overlay {
                if isIncreasedContrast {
                    Capsule().strokeBorder(Color.primary.opacity(0.6), lineWidth: 0.5)
                }
            }
            .accessibilityHidden(true)
    }
}

// MARK: - Player name + total row (for RoundInputView and any single-row name+score display)

/// Displays a player name with their current total in the same badge style as the game scoreboard.
struct PlayerNameWithTotalView: View {
    let name: String
    let total: Int
    let isLeader: Bool
    let colorScheme: ColorScheme
    /// See `PlayerTotalBadge.reservesCrownSpace`.
    var reservesCrownSpace: Bool = true
    /// Name above the total (instead of beside it), for rows too narrow to show both on one line
    /// without squeezing the name to "Al…". `badgeAccessory` (e.g. the 10♦ chip) then sits next to the total.
    var stacked: Bool = false
    var badgeAccessory: AnyView? = nil
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var nameText: some View {
        Text(name)
            .font(.headline.weight(.semibold))
            .lineLimit(1)
            .truncationMode(.tail)
            // At accessibility sizes shrink instead of truncating to "x…" in a narrow pane.
            .minimumScaleFactor(dynamicTypeSize.isAccessibilitySize ? 0.5 : 1)
    }

    private var badge: some View {
        PlayerTotalBadge(total: total, isLeader: isLeader, colorScheme: colorScheme, reservesCrownSpace: reservesCrownSpace)
            .accessibilityIdentifier("playerTotal.\(name)")
    }

    func stackedLayout(accessory: AnyView? = nil) -> PlayerNameWithTotalView {
        var copy = self
        copy.stacked = true
        copy.badgeAccessory = accessory
        return copy
    }

    var body: some View {
        if stacked {
            // The leader's crown overlays the top of the total, so leave room for it under the name.
            VStack(alignment: .leading, spacing: isLeader ? 10 : 2) {
                nameText
                HStack(spacing: 6) {
                    badge
                    badgeAccessory
                }
            }
        } else {
            HStack(spacing: 8) {
                nameText
                badge
            }
        }
    }
}

// MARK: - Score cell pieces (shared by GameView and HistoryDetailView)

/// The text/icon inside a round-score cell: the number, or a moon for a shooter. A shooter who also
/// took the 10♦ gets a small "−10" beside the moon, since the cell shows no number.
struct ScoreCellContent: View {
    let score: Int
    let isMoon: Bool
    /// From `HeartsGame.moonCellTenOfDiamondsBonus`; only meaningful with `isMoon`.
    var moonBonus: Int? = nil
    /// A full-26 hand (a moon victim): bolder text so it stands out without relying on color.
    var emphasize: Bool = false

    var body: some View {
        Group {
            if isMoon {
                HStack(spacing: 3) {
                    Image(systemName: "moon.fill")
                    if let moonBonus {
                        Text("\u{2212}\(abs(moonBonus))")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color.secondary)
                            .monospacedDigit()
                    }
                }
            } else {
                Text("\(score)")
            }
        }
        .font(.footnote.weight(emphasize ? .bold : .medium))
        .foregroundStyle(Color.primary)
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }
}

/// Sizing and 10♦ marker for a score cell. Height and the ♦ glyph scale with Dynamic Type; the width
/// caps at 56pt but shrinks with its column so six players fit narrow panes.
struct ScoreCellFrame: ViewModifier {
    let hasTenOfDiamonds: Bool
    @ScaledMetric(relativeTo: .footnote) private var cellHeight: CGFloat = 26
    @ScaledMetric(relativeTo: .footnote) private var maxCellWidth: CGFloat = 56
    @ScaledMetric(relativeTo: .caption2) private var diamondSize: CGFloat = 9

    func body(content: Content) -> some View {
        content
            // Reserve room on both sides (so the number stays centered) for the ♦ marker to sit clear of the text.
            .padding(.horizontal, hasTenOfDiamonds ? diamondSize * 0.9 : 0)
            .frame(maxWidth: maxCellWidth, minHeight: cellHeight)
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
