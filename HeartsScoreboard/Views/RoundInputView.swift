import SwiftUI
import Observation

struct RoundInputView: View {
    /// How the round-entry UI is hosted.
    enum Presentation {
        /// Own NavigationStack with Back/Reset toolbar; dismisses after submit.
        case sheet
        /// Embedded panel (no NavigationStack); resets for the next round after submit.
        case inline
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Bindable var model: GameViewModel
    let presentation: Presentation

    @ScaledMetric(relativeTo: .body) private var tapSize: CGFloat = 44
    @ScaledMetric(relativeTo: .body) private var stepperSize: CGFloat = 34

    init(model: GameViewModel, presentation: Presentation = .sheet) {
        self.model = model
        self.presentation = presentation
    }

    @State private var points: [UUID: Int] = [:]
    @State private var queenOwnerID: UUID? = nil
    @State private var tenOfDiamondsOwnerID: UUID? = nil

    private var isTenRuleOn: Bool { model.settings.tenOfDiamondsMinus10 }

    private var leadingPlayerIDs: Set<UUID> {
        let totals = model.game.totals()
        guard let minTotal = totals.map(\.total).min() else { return [] }
        return Set(totals.filter { $0.total == minTotal }.map { $0.player.id })
    }

    private var isAllScoresZero: Bool {
        model.game.players.allSatisfy { (points[$0.id] ?? 0) == 0 }
    }

    /// True when the hearts/Q♠ round is valid but the 10♦ holder still has to be chosen.
    private var needsTenOfDiamondsHolder: Bool {
        isTenRuleOn && isRoundValid && tenOfDiamondsOwnerID == nil
    }

    /// Submit needs a valid 26-point round and, when the 10♦ rule is on, a chosen 10♦ holder.
    private var canSubmit: Bool {
        isRoundValid && (!isTenRuleOn || tenOfDiamondsOwnerID != nil)
    }

    var body: some View {
        Group {
            switch presentation {
            case .sheet:
                NavigationStack {
                    content
                        .navigationTitle(roundTitle)
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button {
                                    dismiss()
                                } label: {
                                    Label("Back", systemImage: "chevron.left")
                                }
                            }
                            ToolbarItem(placement: .topBarTrailing) { resetButton }
                        }
                }
                .modifier(FormPresentationSizing())
            case .inline:
                VStack(spacing: 0) {
                    HStack {
                        Text(roundTitle)
                            .font(.headline)
                        Spacer()
                        resetButton
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                    content
                }
            }
        }
        .onAppear {
            if points.isEmpty {
                reset()
            }
        }
    }

    private var roundTitle: String {
        String(format: String(localized: "Round %d"), model.game.hands.count + 1)
    }

    private var resetButton: some View {
        Button {
            reset()
        } label: {
            Label("Reset", systemImage: "arrow.counterclockwise")
        }
        .disabled(isAllScoresZero && tenOfDiamondsOwnerID == nil)
    }

    private var content: some View {
            VStack {
                Form {
                    Section {
                        ForEach(Array(model.game.players.enumerated()), id: \.element.id) { index, player in
                            playerRow(player, index: index)
                        }
                    }

                    if isTenRuleOn {
                        Section {
                            FlowLayout(spacing: 8) {
                                ForEach(model.game.players) { player in
                                    let isSelected = tenOfDiamondsOwnerID == player.id
                                    Button {
                                        tenOfDiamondsOwnerID = isSelected ? nil : player.id
                                    } label: {
                                        Text(player.name)
                                            .lineLimit(1)
                                            .truncationMode(.tail)
                                    }
                                    .buttonStyle(.borderless)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .foregroundStyle(isSelected ? Color.white : Color.accentColor)
                                    .background(
                                        Capsule(style: .continuous)
                                            .fill(isSelected ? Color.accentColor : Color.accentColor.opacity(0.15))
                                    )
                                    .accessibilityLabel(String(format: String(localized: "%@ took the 10 of diamonds"), player.name))
                                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                                }
                            }
                            .padding(.vertical, 2)
                        } header: {
                            Text("10♦ taken by")
                        } footer: {
                            Text("The player who took the 10♦ scores −10 this round.")
                        }
                    }

                    Section("Shoot the Moon Preference") {
                        Picker("Shoot the moon", selection: $model.settings.shootMoonPreference) {
                            ForEach(ShootMoonPreference.allCases) { pref in
                                Text(pref.label).tag(pref)
                            }
                        }
                        .pickerStyle(.segmented)

                        VStack(alignment: .leading, spacing: 4) {
                            if model.settings.shootMoonPreference == .add26 {
                                Text("Adds 26 points to every other players' score.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }

                            if model.settings.shootMoonPreference == .subtract26 {
                                Text("Subtracts 26 points from the selected player's score.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.top, 4)
                    }
                }
                .modifier(InlineFormMargins(isInline: presentation == .inline))

                VStack(spacing: 10) {
                    progressStrip

                    Button {
                        submit()
                    } label: {
                        Text(needsTenOfDiamondsHolder ? "Select who took the 10♦" : "Submit")
                            .font(.headline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .accessibilityLabel(Text("Submit round scores"))
                    .accessibilityIdentifier("roundInput.submit")
                    .disabled(!canSubmit)
                }
                .padding(.horizontal)
                .padding(.vertical)
            }
            .sensoryFeedback(.selection, trigger: points) { old, new in
                // Skip the initial fill and resets (all zeros); only real edits tick.
                !old.isEmpty && old != new && new.values.contains { $0 != 0 }
            }
            .sensoryFeedback(.selection, trigger: tenOfDiamondsOwnerID) { old, new in
                old != new && new != nil
            }
            .sensoryFeedback(.success, trigger: canSubmit) { old, new in
                !old && new
            }
            .onChange(of: canSubmit) { old, new in
                if !old && new {
                    AccessibilityNotification.Announcement(String(localized: "Ready to submit")).post()
                }
            }
    }

    private var totalPoints: Int {
        model.game.players.reduce(0) { $0 + (points[$1.id] ?? 0) }
    }

    /// Progress toward the 26 hearts/Q♠ points. The 10♦ −10 is applied on submit and never counts here.
    private var progressText: String {
        let total = totalPoints
        if isRoundValid {
            if needsTenOfDiamondsHolder { return String(localized: "Choose who took the 10♦") }
            return isShootTheMoonRound ? String(localized: "Shoot the moon") : String(localized: "Ready")
        }
        if total == 26 {
            return String(localized: "One player can't take all 26. Use the moon.")
        }
        if total > 26 {
            return String(format: String(localized: "%d / 26 · %d over"), total, total - 26)
        }
        return String(format: String(localized: "%d / 26 · %d left"), total, 26 - total)
    }

    private var progressStrip: some View {
        let isOver = !isRoundValid && totalPoints > 26
        let isDone = canSubmit
        return HStack(spacing: 6) {
            Image(systemName: isDone ? "checkmark.circle.fill" : (isOver ? "exclamationmark.triangle.fill" : "circle.dashed"))
            Text(progressText)
                .contentTransition(reduceMotion ? .identity : .numericText())
        }
        .font(.subheadline.weight(.medium))
        .monospacedDigit()
        .foregroundStyle(isOver ? Color.red : (isDone ? Color.accentColor : Color.secondary))
        .frame(maxWidth: .infinity)
        .animation(reduceMotion ? nil : .default, value: progressText)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(progressText)
        .accessibilityIdentifier("roundInput.progress")
    }

    @ViewBuilder
    private func playerRow(_ player: HeartsGame.Player, index: Int) -> some View {
        let quick = model.settings.quickIncrementPoints
        let remaining = remainingPoints(for: player.id)
        let nameView = PlayerNameWithTotalView(
            name: player.name,
            total: model.game.totalPoints(for: player.id),
            isLeader: leadingPlayerIDs.contains(player.id),
            colorScheme: colorScheme
        )
        Group {
            if presentation == .inline {
                // Narrow pane (~300pt): name + stepper on one line, the four chips on a second line,
                // so long names never collapse to "…".
                VStack(spacing: 6) {
                    HStack(spacing: 8) {
                        nameView
                            .frame(maxWidth: .infinity, alignment: .leading)
                        stepper(for: player)
                    }
                    HStack(spacing: 6) {
                        quickChip(for: player, quick: quick, remaining: remaining)
                        remainingChip(for: player, remaining: remaining)
                        queenChip(for: player)
                        moonChip(for: player)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.vertical, 4)
            } else {
                HStack(alignment: .center, spacing: 8) {
                    nameView
                        .frame(minWidth: 60, maxWidth: 160, alignment: .leading)
                        .layoutPriority(1)

                    Spacer(minLength: 0)

                    stepper(for: player)

                    Grid(horizontalSpacing: 4, verticalSpacing: 4) {
                        GridRow {
                            quickChip(for: player, quick: quick, remaining: remaining)
                            remainingChip(for: player, remaining: remaining)
                        }
                        GridRow {
                            queenChip(for: player)
                            moonChip(for: player)
                        }
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(player.name)
        .accessibilityValue(String(format: String(localized: "%d points"), points[player.id] ?? 0))
        .accessibilityIdentifier("roundInput.row.\(index)")
    }

    private func quickChip(for player: HeartsGame.Player, quick: Int, remaining: Int) -> some View {
        Button("+\(quick)") {
            adjustPoints(for: player.id, delta: quick)
        }
        .accessibilityLabel(String(format: String(localized: "Add %d points to %@"), quick, player.name))
        .accessibilityIdentifier("roundInput.quick.\(player.name)")
        .chipStyle(minWidth: tapSize, fill: presentation == .inline)
        .disabled(isRoundValid || remaining < quick)
    }

    private func remainingChip(for player: HeartsGame.Player, remaining: Int) -> some View {
        Button {
            addRemainingPoints(for: player.id)
        } label: {
            Text(isShootTheMoonRound ? "+0" : "+\(remaining)")
        }
        .accessibilityLabel(String(format: String(localized: "Add %d points to %@"), remaining, player.name))
        .chipStyle(minWidth: tapSize, fill: presentation == .inline)
        .disabled(remaining == 0 || isRoundValid)
    }

    private func queenChip(for player: HeartsGame.Player) -> some View {
        Button("Q♠") {
            addQueenOfSpades(for: player.id)
        }
        .accessibilityLabel(String(format: String(localized: "Queen of spades to %@"), player.name))
        .accessibilityIdentifier("roundInput.queen.\(player.name)")
        .chipStyle(minWidth: tapSize, fill: presentation == .inline)
        .disabled(isRoundValid || queenOwnerID != nil)
    }

    private func moonChip(for player: HeartsGame.Player) -> some View {
        Button {
            applyShootMoonValue(for: player.id)
        } label: {
            Image(systemName: "moon.fill")
        }
        .accessibilityLabel(String(format: String(localized: "Shoot the moon for %@"), player.name))
        .chipStyle(minWidth: tapSize, fill: presentation == .inline)
        .disabled(isRoundValid)
    }

    private func stepper(for player: HeartsGame.Player) -> some View {
        HStack(spacing: 0) {
            Button {
                adjustPoints(for: player.id, delta: -1)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.title3.weight(.semibold))
                    .frame(width: stepperSize, height: tapSize)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(String(format: String(localized: "Decrease points for %@"), player.name))
            .foregroundStyle(isShootTheMoonRound || (points[player.id] ?? 0) == 0 ? Color.secondary.opacity(0.5) : Color.red)
            .disabled(isShootTheMoonRound || (points[player.id] ?? 0) == 0)

            Text("\(points[player.id] ?? 0)")
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(minWidth: 30)
                .overlay(alignment: .top) {
                    if isTenRuleOn && tenOfDiamondsOwnerID == player.id {
                        Text("−10")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color.red)
                            .fixedSize()
                            .offset(y: -16)
                    }
                }

            Button {
                adjustPoints(for: player.id, delta: 1)
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title3.weight(.semibold))
                    .frame(width: stepperSize, height: tapSize)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(String(format: String(localized: "Increase points for %@"), player.name))
            .foregroundStyle(isRoundValid ? Color.secondary.opacity(0.5) : Color.accentColor)
            .disabled(isRoundValid)
        }
    }

    private func adjustPoints(for playerID: UUID, delta: Int) {
        let current = points[playerID] ?? 0
        let newValue = max(0, min(26, current + delta))
        points[playerID] = newValue
    }

    private func setPoints(for playerID: UUID, to value: Int) {
        let newValue = max(0, min(26, value))
        points[playerID] = newValue
    }

    private func addQueenOfSpades(for playerID: UUID) {
        adjustPoints(for: playerID, delta: 13)
        if queenOwnerID == nil {
            queenOwnerID = playerID
        }
    }

    private func remainingPoints(for playerID: UUID) -> Int {
        let total = model.game.players.reduce(0) { $0 + (points[$1.id] ?? 0) }
        let remaining = 26 - total
        return max(0, remaining)
    }

    private func addRemainingPoints(for playerID: UUID) {
        let delta = remainingPoints(for: playerID)
        guard delta > 0 else { return }
        adjustPoints(for: playerID, delta: delta)
    }

    /// Shoot the moon: Add 26 = shooter gets 0, everyone else gets 26. Subtract 26 = shooter gets -26, everyone else gets 0.
    private func applyShootMoonValue(for shooterID: UUID) {
        switch model.settings.shootMoonPreference {
        case .add26:
            for p in model.game.players {
                points[p.id] = p.id == shooterID ? 0 : 26
            }
        case .subtract26:
            for p in model.game.players {
                points[p.id] = p.id == shooterID ? -26 : 0
            }
        }
    }

    /// Valid Hearts round, judged on hearts/Q♠ points only (the 10♦ bonus is applied on submit).
    private var isRoundValid: Bool {
        HeartsGame.isValidRound(penaltyScores: model.game.players.map { points[$0.id] ?? 0 })
    }

    /// True when the round is valid and is a shoot-the-moon outcome (not a normal 26 split). Subtract buttons should be disabled in this case.
    private var isShootTheMoonRound: Bool {
        let n = model.game.players.count
        guard n > 0, isRoundValid else { return false }
        let sum = model.game.players.reduce(0) { $0 + (points[$1.id] ?? 0) }
        return sum == -26 || sum == (n - 1) * 26
    }

    private func reset() {
        var dict: [UUID: Int] = [:]
        for p in model.game.players {
            dict[p.id] = 0
        }
        points = dict
        queenOwnerID = nil
        tenOfDiamondsOwnerID = nil
    }

    private func submit() {
        model.addHand(
            pointsByPlayerID: points,
            tenOfDiamondsPlayerID: isTenRuleOn ? tenOfDiamondsOwnerID : nil
        )
        switch presentation {
        case .sheet: dismiss()
        case .inline: reset()
        }
    }
}

private extension View {
    /// Prominent compact chip button that grows with Dynamic Type but keeps a minimum tap width.
    func chipStyle(minWidth: CGFloat, fill: Bool = false) -> some View {
        self.buttonStyle(.borderedProminent)
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .allowsTightening(true)
            .frame(minWidth: minWidth, maxWidth: fill ? .infinity : nil, minHeight: 32)
    }
}

/// Inline panel has its own title row, so drop the Form's default top inset.
private struct InlineFormMargins: ViewModifier {
    let isInline: Bool
    func body(content: Content) -> some View {
        if isInline {
            content.contentMargins(.top, 0, for: .scrollContent)
        } else {
            content
        }
    }
}

/// Applies `.presentationSizing(.form)` on iOS 18+; no-op on iOS 17.
private struct FormPresentationSizing: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.presentationSizing(.form)
        } else {
            content
        }
    }
}

/// Wraps children onto multiple lines; each child is proposed at most the container width so long names truncate.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(width: proposal.width ?? .infinity, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(width: bounds.width, subviews: subviews)
        for (subview, origin) in zip(subviews, result.origins) {
            subview.place(
                at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y),
                proposal: ProposedViewSize(width: min(bounds.width, origin.maxWidth), height: nil)
            )
        }
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> (size: CGSize, origins: [(x: CGFloat, y: CGFloat, maxWidth: CGFloat)]) {
        var origins: [(x: CGFloat, y: CGFloat, maxWidth: CGFloat)] = []
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, usedWidth: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(ProposedViewSize(width: width, height: nil))
            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            origins.append((x, y, size.width))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            usedWidth = max(usedWidth, x - spacing)
        }
        return (CGSize(width: usedWidth, height: y + rowHeight), origins)
    }
}

#Preview {
    RoundInputView(model: GameViewModel())
}

