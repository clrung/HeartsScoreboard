import SwiftUI

/// The scoreboard card on the felt: a pinned standings header (name, dealer badge, large total, progress
/// toward the ending score) above a round grid of plain numbers on full-width zebra rows.
///
/// Regular width: the card hugs its content (top-aligned) and only scrolls the round grid, under the
/// pinned header, once the rounds no longer fit. Compact width: the card fills the height it is given.
struct ScoreboardCard: View {
    let model: GameViewModel
    /// Width the card is laid out at; sizes the totals and decides between full names and initials.
    let width: CGFloat
    /// Regular-width layout: shows the pending row for the round being entered and hugs its content.
    let isSplit: Bool
    let onEdit: (UUID) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .title) private var totalSize: CGFloat = 34
    @ScaledMetric(relativeTo: .body) private var rowHeight: CGFloat = 36
    @ScaledMetric(relativeTo: .caption) private var crownSize: CGFloat = 13

    private var gutter: CGFloat { isSplit ? Theme.Spacing.l : Theme.Spacing.s }
    private var railWidth: CGFloat { 30 }
    private var players: [HeartsGame.Player] { model.game.players }
    private var columnWidth: CGFloat {
        max(40, (width - 2 * gutter - railWidth) / CGFloat(max(1, players.count)))
    }
    private var showsInitials: Bool { columnWidth < 74 && players.count >= 5 }
    private var labels: [String] { HeartsGame.headerLabels(for: players.map(\.name)) }
    private var hasContrast: Bool { contrast == .increased }
    private var showsPendingRow: Bool { isSplit && !model.isGameOver }

    /// One column per player can't hold accessibility-size totals once 5-6 players share a phone-width
    /// card, so crowded boards stop growing at a size that still fits.
    private var maxTypeSize: DynamicTypeSize {
        if players.count <= 4 { return .accessibility2 }
        return isSplit ? .large : .xxxLarge
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
        let shadow = Theme.Elevation.card(for: colorScheme)
        Group {
            if isSplit {
                ViewThatFits(in: .vertical) {
                    content(scrolling: false)
                    content(scrolling: true)
                }
            } else {
                content(scrolling: true)
            }
        }
        .background(Theme.cardSurface)
        .clipShape(shape)
        .overlay(
            shape.strokeBorder(
                hasContrast ? Color.primary.opacity(0.6) : Color.primary.opacity(colorScheme == .dark ? 0.14 : 0.07),
                lineWidth: hasContrast ? 2 : 1
            )
        )
        .shadow(color: shadow.color, radius: shadow.radius, x: 0, y: shadow.y)
        .dynamicTypeSize(...maxTypeSize)
    }

    private func content(scrolling: Bool) -> some View {
        VStack(spacing: 0) {
            standingsHeader
            Rectangle()
                .fill(Color.primary.opacity(hasContrast ? 0.5 : 0.10))
                .frame(height: 1)
                .accessibilityHidden(true)
            if scrolling {
                ScrollViewReader { proxy in
                    ScrollView {
                        grid
                    }
                    .scrollIndicators(.visible)
                    .onAppear { scrollToLatest(proxy, animated: false) }
                    .onChange(of: model.game.hands.count) { scrollToLatest(proxy, animated: true) }
                }
                .frame(maxHeight: .infinity)
            } else {
                grid
            }
        }
    }

    private func scrollToLatest(_ proxy: ScrollViewProxy, animated: Bool) {
        let target: AnyHashable? = showsPendingRow ? "pending" : model.game.hands.last?.id
        guard let target else { return }
        if animated && !reduceMotion {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { proxy.scrollTo(target, anchor: .bottom) }
        } else {
            proxy.scrollTo(target, anchor: .bottom)
        }
    }

    // MARK: Standings header

    private var standingsHeader: some View {
        let leaders = model.leadingPlayerIDs
        let dealer = model.currentDealerIndex
        return HStack(alignment: .top, spacing: 0) {
            Color.clear.frame(width: railWidth, height: 1)
            ForEach(Array(players.enumerated()), id: \.element.id) { index, player in
                column(player: player, label: showsInitials ? labels[index] : player.name,
                       isDealer: index == dealer, isLeader: leaders.contains(player.id))
            }
        }
        .padding(.horizontal, gutter)
        .padding(.top, Theme.Spacing.m)
        .padding(.bottom, Theme.Spacing.m)
        .background(Theme.cardInset)
    }

    private func column(player: HeartsGame.Player, label: String, isDealer: Bool, isLeader: Bool) -> some View {
        let total = model.game.totalPoints(for: player.id)
        return VStack(spacing: Theme.Spacing.s) {
            HStack(spacing: Theme.Spacing.xs) {
                if isDealer { dealerBadge }
                Text(label)
                    .font((columnWidth < 100 ? Font.subheadline : Font.headline).weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .truncationMode(.tail)
                    .accessibilityLabel(player.name)
                    .accessibilityAddTraits(.isHeader)
            }
            .frame(maxWidth: .infinity)

            VStack(spacing: Theme.Spacing.s) {
                totalWell(total: total, isLeader: isLeader)
                progress(for: player.id)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("\(total)"))
            .accessibilityValue(Text(accessibilityValue(for: player.id, isLeader: isLeader)))
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 3)
    }

    private var dealerBadge: some View {
        Text("D")
            .font(.caption2.weight(.heavy))
            .foregroundStyle(.white)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Capsule().fill(Theme.dealerBadgeGradient(for: colorScheme)))
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.4), lineWidth: 0.5))
            .accessibilityLabel(Text("Dealer"))
    }

    private func totalWell(total: Int, isLeader: Bool) -> some View {
        let size = min(totalSize, columnWidth * 0.36)
        let well = RoundedRectangle(cornerRadius: Theme.Radius.well, style: .continuous)
        return Text("\(total)")
            .font(.system(size: size, weight: .bold, design: .rounded))
            .monospacedDigit()
            .contentTransition(.numericText(value: Double(total)))
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .foregroundStyle(Color.primary)
            .padding(.horizontal, Theme.Spacing.s)
            .padding(.vertical, Theme.Spacing.xs)
            .frame(maxWidth: .infinity)
            .background(well.fill(isLeader ? Theme.leaderWell : Color.clear))
            .overlay(well.strokeBorder(isLeader ? Theme.leader : Color.clear, lineWidth: hasContrast ? 2 : 1.5))
            .overlay(alignment: .top) {
                if isLeader {
                    Image(systemName: "crown.fill")
                        .font(.system(size: crownSize, weight: .bold))
                        .foregroundStyle(Theme.leader)
                        .padding(3)
                        .background(Circle().fill(Color(red: 0.10, green: 0.16, blue: 0.12)))
                        .offset(y: -crownSize * 0.95)
                        .accessibilityHidden(true)
                }
            }
            .padding(.top, crownSize * 0.9)
            .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.85), value: total)
    }

    private func progress(for id: UUID) -> some View {
        let fraction = model.progress(for: id)
        return VStack(spacing: Theme.Spacing.xs) {
            Capsule()
                .fill(Color.primary.opacity(hasContrast ? 0.35 : 0.13))
                .frame(height: hasContrast ? 6 : 4)
                .overlay(alignment: .leading) {
                    GeometryReader { geo in
                        Capsule().fill(barColor(fraction)).frame(width: geo.size.width * fraction)
                    }
                }
                .padding(.horizontal, Theme.Spacing.xs)
            if !model.isGameOver && columnWidth >= 78 {
                Text(String(format: String(localized: "%d to go"), model.pointsRemaining(for: id)))
                    .font(.caption2.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(Color.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
    }

    private func barColor(_ progress: Double) -> Color {
        if progress >= 0.9 { return Color(red: 0.80, green: 0.12, blue: 0.12) }
        if progress >= 0.75 { return Color(red: 0.90, green: 0.55, blue: 0.0) }
        return Theme.positive
    }

    private func accessibilityValue(for id: UUID, isLeader: Bool) -> String {
        var parts: [String] = []
        if isLeader { parts.append(String(localized: "Leading")) }
        if !model.isGameOver { parts.append(String(format: String(localized: "%d to go"), model.pointsRemaining(for: id))) }
        return parts.joined(separator: ", ")
    }

    // MARK: Round grid

    private var grid: some View {
        VStack(spacing: 0) {
            ForEach(Array(model.game.hands.enumerated()), id: \.element.id) { index, hand in
                roundRow(index: index, hand: hand)
            }
            if showsPendingRow {
                pendingRow(index: model.game.hands.count)
            }
            if model.game.hands.isEmpty {
                emptyState
            }
        }
        .padding(.bottom, Theme.Spacing.xs)
        .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.85), value: model.game.hands.count)
    }

    private func zebra(_ index: Int) -> Color { index.isMultiple(of: 2) ? Color.clear : Theme.rowZebra }

    private func roundRow(index: Int, hand: HeartsGame.Hand) -> some View {
        HStack(spacing: 0) {
            Text("\(index + 1)")
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(Color.secondary)
                .frame(width: railWidth, height: rowHeight)
                .contentShape(Rectangle())
                .onTapGesture { onEdit(hand.id) }
                .accessibilityHidden(true) // the score cells carry the "edit round" action
            ForEach(players) { player in
                cell(index: index, hand: hand, player: player)
            }
        }
        .padding(.horizontal, gutter)
        .background(zebra(index))
        .id(hand.id)
    }

    private func cell(index: Int, hand: HeartsGame.Hand, player: HeartsGame.Player) -> some View {
        let score = hand.pointsByPlayerID[player.id] ?? 0
        let isMoon = model.game.isMoonHand(hand, for: player.id)
        let tookTen = hand.tenOfDiamondsPlayerID == player.id
        let tookAll = score == 26 && !isMoon
        return Group {
            if isMoon {
                HStack(spacing: 3) {
                    Image(systemName: "moon.fill").foregroundStyle(Theme.moon)
                    if let bonus = model.game.moonCellTenOfDiamondsBonus(hand, for: player.id) {
                        Text("\u{2212}\(abs(bonus))")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color.secondary)
                            .monospacedDigit()
                    }
                }
            } else {
                Text("\(score)")
                    .foregroundStyle(tookAll ? Color.primary : (score == 0 ? Color.secondary : Color.primary))
            }
        }
        .font(.system(.body, design: .rounded).weight(tookAll ? .bold : .medium))
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .overlay(alignment: .topTrailing) {
            if tookTen {
                Text("♦")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.red)
                    .offset(x: 10, y: -3)
            }
        }
        .padding(.horizontal, tookTen ? 10 : 0)
        .frame(maxWidth: .infinity, minHeight: rowHeight)
        .background {
            if tookAll {
                RoundedRectangle(cornerRadius: Theme.Radius.cell, style: .continuous)
                    .fill(Theme.allPointsFill)
                    .padding(.vertical, 3)
                    .padding(.horizontal, 3)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onEdit(hand.id) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(cellAccessibilityLabel(round: index + 1, playerName: player.name, score: score,
                                                   isMoon: isMoon, tookTenOfDiamonds: tookTen))
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(Text("Edit this round"))
    }

    private func pendingRow(index: Int) -> some View {
        HStack(spacing: 0) {
            Text("\(index + 1)")
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(Color.secondary)
                .frame(width: railWidth)
            RoundedRectangle(cornerRadius: Theme.Radius.cell, style: .continuous)
                .strokeBorder(Color.secondary.opacity(hasContrast ? 0.9 : 0.5), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                .padding(.vertical, 3)
        }
        .frame(height: rowHeight)
        .padding(.horizontal, gutter)
        .background(zebra(index))
        .id("pending")
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var emptyState: some View {
        if isSplit {
            HStack(spacing: Theme.Spacing.s) {
                Text("Enter round 1 scores")
                Image(systemName: "arrow.forward")
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(Color.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.l)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("emptyRoundsLabel")
        } else {
            Text("No rounds yet")
                .font(.subheadline)
                .foregroundStyle(Color.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 120)
                .accessibilityIdentifier("emptyRoundsLabel")
        }
    }

    private func cellAccessibilityLabel(round: Int, playerName: String, score: Int, isMoon: Bool, tookTenOfDiamonds: Bool) -> String {
        if isMoon {
            return String(format: String(localized: "Round %d, %@: shot the moon"), round, playerName)
        }
        var label = String(format: String(localized: "Round %d, %@: %d points"), round, playerName, score)
        if tookTenOfDiamonds { label += String(localized: ", took the 10 of diamonds") }
        return label
    }
}
