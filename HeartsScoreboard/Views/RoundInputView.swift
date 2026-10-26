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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Bindable var model: GameViewModel
    let presentation: Presentation
    /// When set, the sheet edits this existing round (pre-filled, "Save" instead of "Submit").
    let editingHandID: UUID?

    @ScaledMetric(relativeTo: .body) private var tapSize: CGFloat = 44
    @ScaledMetric(relativeTo: .body) private var stepperSize: CGFloat = 34
    /// Min chip width: wide enough for "+26" (the widest chip text), scaling with Dynamic Type.
    @ScaledMetric(relativeTo: .subheadline) private var chipWidth: CGFloat = ChipMetrics.baseMinWidth

    init(model: GameViewModel, presentation: Presentation = .sheet, editingHandID: UUID? = nil) {
        self.model = model
        self.presentation = presentation
        self.editingHandID = editingHandID
    }

    private var isEditing: Bool { editingHandID != nil }

    /// The round being edited; nil if it vanished (e.g. removed by an iCloud sync while the sheet was open).
    private var editedHandIndex: Int? {
        guard let id = editingHandID else { return nil }
        return model.game.hands.firstIndex(where: { $0.id == id })
    }

    @State private var entry = RoundEntryState()

    private var isAccessibilitySize: Bool { dynamicTypeSize.isAccessibilitySize }

    /// Inline is always stacked (narrow pane); the sheet stacks only at accessibility sizes, where
    /// the one-line sheet row can't hold the name, stepper and chips.
    private var stacksRow: Bool { presentation == .inline || isAccessibilitySize }

    private var isTenRuleOn: Bool { model.settings.tenOfDiamondsMinus10 }

    private var leadingPlayerIDs: Set<UUID> { model.leadingPlayerIDs(excluding: editingHandID) }

    /// Edit mode right after the sheet pre-fills the round: the entry is valid but the user hasn't
    /// done anything yet, so "ready to submit" feedback would be noise.
    private var isUntouchedEdit: Bool {
        guard let index = editedHandIndex else { return false }
        return entry == RoundEntryState(hand: model.game.hands[index], players: model.game.players)
    }

    private var isAllScoresZero: Bool {
        model.game.players.allSatisfy { (entry.points[$0.id] ?? 0) == 0 }
    }

    /// True when the hearts/Q♠ round is valid but the 10♦ holder still has to be chosen.
    private var needsTenOfDiamondsHolder: Bool {
        isTenRuleOn && isRoundValid && entry.tenOfDiamondsOwnerID == nil
    }

    /// Submit needs a valid 26-point round and, when the 10♦ rule is on, a chosen 10♦ holder.
    private var canSubmit: Bool {
        entry.canSubmit(players: model.game.players, tenRuleOn: isTenRuleOn)
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
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        Spacer(minLength: 8)
                        resetButton
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                    content
                }
            }
        }
        .onAppear {
            if entry.points.isEmpty {
                if let index = editedHandIndex {
                    entry = RoundEntryState(hand: model.game.hands[index], players: model.game.players)
                } else {
                    reset()
                }
            }
        }
        .onChange(of: editedHandIndex == nil) { _, missing in
            if isEditing && missing { dismiss() }
        }
    }

    private var roundTitle: String {
        if let index = editedHandIndex {
            return String(format: String(localized: "Edit Round %d"), index + 1)
        }
        return String(format: String(localized: "Round %d"), model.game.hands.count + 1)
    }

    private var resetButton: some View {
        Button {
            reset()
        } label: {
            if isAccessibilitySize {
                // Icon-only when the text would wrap; Label keeps "Reset" as the accessibility label.
                Label("Reset", systemImage: "arrow.counterclockwise").labelStyle(.iconOnly)
            } else {
                Label("Reset", systemImage: "arrow.counterclockwise")
            }
        }
        .disabled(isAllScoresZero && entry.tenOfDiamondsOwnerID == nil)
    }

    private var content: some View {
            submitLayout {
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
                                    tenOfDiamondsButton(for: player)
                                }
                            }
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

            } bar: {
                VStack(spacing: 10) {
                    progressStrip

                    Button {
                        submit()
                    } label: {
                        Text(needsTenOfDiamondsHolder ? "Select who took the 10♦" : (isEditing ? "Save" : "Submit"))
                            .font(.headline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .keyboardShortcut(.return, modifiers: .command)
                    .accessibilityLabel(isEditing ? Text("Save round scores") : Text("Submit round scores"))
                    .accessibilityIdentifier("roundInput.submit")
                    .disabled(!canSubmit)
                }
                .padding(.horizontal)
                .padding(.vertical)
            }
            .sensoryFeedback(.selection, trigger: entry.points) { old, new in
                // Skip the initial fill and resets (all zeros); only real edits tick.
                !old.isEmpty && old != new && new.values.contains { $0 != 0 }
            }
            .sensoryFeedback(.selection, trigger: entry.tenOfDiamondsOwnerID) { old, new in
                old != new && new != nil
            }
            .sensoryFeedback(.success, trigger: canSubmit) { old, new in
                !old && new && !isUntouchedEdit
            }
            .onChange(of: canSubmit) { old, new in
                if !old && new && !isUntouchedEdit {
                    Announcer.post(String(localized: "Ready to submit"))
                }
            }
    }

    /// Lays out the form and the pinned progress/Submit bar. Inline uses a bottom safe-area inset so the
    /// form's scroll content is inset clear of the bar (the last rows can always be scrolled fully into view);
    /// the sheet keeps its plain stacked layout.
    @ViewBuilder
    private func submitLayout<Body: View, Bar: View>(
        @ViewBuilder _ body: () -> Body,
        @ViewBuilder bar: () -> Bar
    ) -> some View {
        if presentation == .inline {
            body().safeAreaInset(edge: .bottom, spacing: 0) {
                bar().background(Color(.systemGroupedBackground))
            }
        } else {
            VStack {
                body()
                bar()
            }
        }
    }

    private var totalPoints: Int {
        model.game.players.reduce(0) { $0 + (entry.points[$1.id] ?? 0) }
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
            total: model.game.totalPoints(for: player.id, excluding: editingHandID),
            isLeader: leadingPlayerIDs.contains(player.id),
            colorScheme: colorScheme
        )
        Group {
            if isAccessibilitySize {
                // Accessibility sizes: name + total, then the stepper, then the chips in a 2x2 grid.
                VStack(alignment: .leading, spacing: 0) {
                    nameView
                    stepper(for: player)
                    Grid(horizontalSpacing: 6, verticalSpacing: 0) {
                        GridRow {
                            quickChip(for: player, quick: quick, remaining: remaining)
                            remainingChip(for: player, remaining: remaining)
                        }
                        GridRow {
                            queenChip(for: player)
                            moonChip(for: player)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 2, trailing: 16))
            } else if presentation == .inline {
                // Narrow pane (~300pt): name + stepper on one line, the four chips on a second line,
                // so long names never collapse to "…".
                VStack(spacing: 0) {
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
                .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 2, trailing: 16))
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
        .accessibilityValue(String(format: String(localized: "%d points"), entry.points[player.id] ?? 0))
        .accessibilityIdentifier("roundInput.row.\(index)")
    }

    private func tenOfDiamondsButton(for player: HeartsGame.Player) -> some View {
        let isSelected = entry.tenOfDiamondsOwnerID == player.id
        return Button {
            entry.tenOfDiamondsOwnerID = isSelected ? nil : player.id
        } label: {
            Text(player.name)
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .foregroundStyle(isSelected ? Color.white : Color.accentColor)
                .background(
                    Capsule(style: .continuous)
                        .fill(isSelected ? Color.accentColor : Color.accentColor.opacity(0.15))
                )
                // Visual capsule stays compact; the hit area is a full 44pt.
                .frame(minHeight: 44)
                .contentShape(Rectangle())
                .contentShape(.hoverEffect, Capsule(style: .continuous))
                .hoverEffect()
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(String(format: String(localized: "%@ took the 10 of diamonds"), player.name))
        .accessibilityIdentifier("roundInput.ten.\(player.name)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func quickChip(for player: HeartsGame.Player, quick: Int, remaining: Int) -> some View {
        Button("+\(quick)") {
            adjustPoints(for: player.id, delta: quick)
        }
        .accessibilityLabel(String(format: String(localized: "Add %d points to %@"), quick, player.name))
        .accessibilityIdentifier("roundInput.quick.\(player.name)")
        .chipStyle(minWidth: max(tapSize, chipWidth), fill: stacksRow)
        .disabled(isRoundValid || remaining < quick)
    }

    private func remainingChip(for player: HeartsGame.Player, remaining: Int) -> some View {
        Button {
            addRemainingPoints(for: player.id)
        } label: {
            Text(isShootTheMoonRound ? "+0" : "+\(remaining)")
        }
        .accessibilityLabel(String(format: String(localized: "Add %d points to %@"), remaining, player.name))
        .accessibilityIdentifier("roundInput.remaining.\(player.name)")
        .chipStyle(minWidth: max(tapSize, chipWidth), fill: stacksRow)
        .disabled(remaining == 0 || isRoundValid)
    }

    private func queenChip(for player: HeartsGame.Player) -> some View {
        Button("Q♠") {
            addQueenOfSpades(for: player.id)
        }
        .accessibilityLabel(String(format: String(localized: "Queen of spades to %@"), player.name))
        .accessibilityIdentifier("roundInput.queen.\(player.name)")
        .chipStyle(minWidth: max(tapSize, chipWidth), fill: stacksRow)
        .disabled(isRoundValid || entry.queenOwnerID != nil)
    }

    private func moonChip(for player: HeartsGame.Player) -> some View {
        Button {
            applyShootMoonValue(for: player.id)
        } label: {
            Image(systemName: "moon.fill")
        }
        .accessibilityLabel(String(format: String(localized: "Shoot the moon for %@"), player.name))
        .chipStyle(minWidth: max(tapSize, chipWidth), fill: stacksRow)
        .disabled(isRoundValid)
    }

    private func stepper(for player: HeartsGame.Player) -> some View {
        HStack(spacing: 0) {
            HoldRepeatButton {
                adjustPoints(for: player.id, delta: -1)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.title3.weight(.semibold))
                    .frame(width: stepperSize, height: tapSize)
                    .contentShape(Rectangle())
                    .hoverEffect()
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(String(format: String(localized: "Decrease points for %@"), player.name))
            .accessibilityIdentifier("roundInput.decrease.\(player.name)")
            .foregroundStyle(isShootTheMoonRound || (entry.points[player.id] ?? 0) == 0 ? Color.secondary.opacity(0.5) : Color.red)
            .disabled(isShootTheMoonRound || (entry.points[player.id] ?? 0) == 0)

            Text("\(entry.points[player.id] ?? 0)")
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                // Full tap height so the −10 badge sits inside the row; an offset above it got clipped by the list cell.
                .frame(minWidth: 30, minHeight: tapSize)
                .overlay(alignment: .top) {
                    if isTenRuleOn && entry.tenOfDiamondsOwnerID == player.id {
                        Text("−10")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color.red)
                            .fixedSize()
                            .accessibilityIdentifier("roundInput.tenBadge.\(player.name)")
                    }
                }

            HoldRepeatButton {
                adjustPoints(for: player.id, delta: 1)
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title3.weight(.semibold))
                    .frame(width: stepperSize, height: tapSize)
                    .contentShape(Rectangle())
                    .hoverEffect()
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(String(format: String(localized: "Increase points for %@"), player.name))
            .foregroundStyle(isRoundValid ? Color.secondary.opacity(0.5) : Color.accentColor)
            .disabled(isRoundValid)
        }
    }

    private func adjustPoints(for playerID: UUID, delta: Int) {
        let current = entry.points[playerID] ?? 0
        let newValue = max(0, min(26, current + delta))
        entry.points[playerID] = newValue
    }

    private func setPoints(for playerID: UUID, to value: Int) {
        let newValue = max(0, min(26, value))
        entry.points[playerID] = newValue
    }

    private func addQueenOfSpades(for playerID: UUID) {
        adjustPoints(for: playerID, delta: 13)
        if entry.queenOwnerID == nil {
            entry.queenOwnerID = playerID
        }
    }

    private func remainingPoints(for playerID: UUID) -> Int {
        let total = model.game.players.reduce(0) { $0 + (entry.points[$1.id] ?? 0) }
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
                entry.points[p.id] = p.id == shooterID ? 0 : 26
            }
        case .subtract26:
            for p in model.game.players {
                entry.points[p.id] = p.id == shooterID ? -26 : 0
            }
        }
    }

    /// Valid Hearts round, judged on hearts/Q♠ points only (the 10♦ bonus is applied on submit).
    private var isRoundValid: Bool {
        entry.isRoundValid(players: model.game.players)
    }

    /// True when the round is valid and is a shoot-the-moon outcome (not a normal 26 split). Subtract buttons should be disabled in this case.
    private var isShootTheMoonRound: Bool {
        let n = model.game.players.count
        guard n > 0, isRoundValid else { return false }
        let sum = model.game.players.reduce(0) { $0 + (entry.points[$1.id] ?? 0) }
        return sum == -26 || sum == (n - 1) * 26
    }

    private func reset() {
        entry.reset(players: model.game.players)
    }

    private func submit() {
        if let id = editingHandID {
            guard let index = editedHandIndex, entry.save(over: id, in: model) else { return }
            Announcer.post(GameViewModel.updatedAnnouncement(round: index + 1))
            dismiss()
            return
        }
        guard entry.submit(to: model) else { return }
        switch presentation {
        case .sheet: dismiss()
        case .inline: reset()
        }
    }
}

/// Sizing for the score chips. The width is derived from the widest chip text ("+26") so it is never truncated.
enum ChipMetrics {
    static let horizontalPadding: CGFloat = 10
    /// Subheadline's base point size (15pt at the default Dynamic Type size).
    static let baseFontSize: CGFloat = 15
    static let widestText = "+26"

    /// Width of `widestText` in the chip font (semibold) at `fontSize`, plus the capsule padding.
    static func minWidth(fontSize: CGFloat = baseFontSize) -> CGFloat {
        let font = UIFont.systemFont(ofSize: fontSize, weight: .semibold)
        let text = (widestText as NSString).size(withAttributes: [.font: font]).width
        return ceil(text) + 2 * horizontalPadding
    }

    static var baseMinWidth: CGFloat { minWidth() }
}

private extension View {
    /// Compact capsule chip that grows with Dynamic Type but keeps a minimum tap width, with a full 44pt hit area.
    func chipStyle(minWidth: CGFloat, fill: Bool = false) -> some View {
        self.buttonStyle(ChipButtonStyle(minWidth: minWidth, fill: fill))
    }
}

/// Filled capsule (32pt tall) inside a 44pt-tall hit area, so rows stay compact without a small tap target.
private struct ChipButtonStyle: ButtonStyle {
    let minWidth: CGFloat
    let fill: Bool
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .allowsTightening(true)
            .foregroundStyle(isEnabled ? Color.white : Color.secondary)
            .padding(.horizontal, ChipMetrics.horizontalPadding)
            .frame(minWidth: minWidth, maxWidth: fill ? .infinity : nil, minHeight: 32)
            .background(
                Capsule(style: .continuous)
                    .fill(isEnabled ? Color.accentColor : Color.secondary.opacity(0.25))
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
            .contentShape(.hoverEffect, Capsule(style: .continuous))
            .hoverEffect()
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

