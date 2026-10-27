import SwiftUI
import Observation

struct RoundInputView: View {
    /// How the round-entry UI is hosted.
    enum Presentation {
        /// Own NavigationStack with Back/Reset toolbar; dismisses after submit.
        case sheet
        /// Embedded card (no NavigationStack) that hugs its content; resets for the next round after submit.
        case inline
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorSchemeContrast) private var contrast
    @Bindable var model: GameViewModel
    let presentation: Presentation
    /// When set, the sheet edits this existing round (pre-filled, "Save" instead of "Submit").
    let editingHandID: UUID?

    @ScaledMetric(relativeTo: .body) private var tapSize: CGFloat = 44
    @ScaledMetric(relativeTo: .title) private var wellWidth: CGFloat = 62
    @ScaledMetric(relativeTo: .title) private var wellFontSize: CGFloat = 26
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
    /// The player whose value-picker popover is open.
    @State private var valuePickerPlayerID: UUID?

    private var isAccessibilitySize: Bool { dynamicTypeSize.isAccessibilitySize }

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
                    sheetContent
                        .navigationTitle(roundTitle)
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button {
                                    dismiss()
                                } label: {
                                    Label("Back", systemImage: DirectionalUI.backSymbol)
                                }
                            }
                            ToolbarItem(placement: .topBarTrailing) { resetButton }
                        }
                }
                .modifier(FormPresentationSizing())
            case .inline:
                // Hugs its content; only when rows + header + footer exceed the height does it scroll.
                ViewThatFits(in: .vertical) {
                    inlineContent(scrolling: false)
                    inlineContent(scrolling: true)
                }
            }
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
        .onAppear {
            if entry.points.isEmpty {
                if let index = editedHandIndex {
                    entry = RoundEntryState(hand: model.game.hands[index], players: model.game.players)
                } else {
                    reset()
                    #if DEBUG
                    // UI tests only: `-screenshotTenHolder <name>` pre-selects the 10♦ holder.
                    if isTenRuleOn, let i = CommandLine.arguments.firstIndex(of: "-screenshotTenHolder"),
                       CommandLine.arguments.indices.contains(i + 1) {
                        entry.tenOfDiamondsOwnerID = model.game.players.first { $0.name == CommandLine.arguments[i + 1] }?.id
                    }
                    #endif
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

    // MARK: Layout

    private var sheetContent: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer(minLength: 0)
                moonMenu
            }
            .padding(.horizontal, Theme.Spacing.l)
            ScrollView {
                entryRows
                    .padding(.horizontal, Theme.Spacing.l)
                    .padding(.bottom, Theme.Spacing.m)
            }
            .scrollBounceBehavior(.basedOnSize)
            .accessibilityIdentifier("roundInput.scroll")
            footer
        }
        .background(Theme.cardSurface.ignoresSafeArea())
    }

    private func inlineContent(scrolling: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: Theme.Spacing.s) {
                Text(roundTitle)
                    .font(.title2.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Spacer(minLength: Theme.Spacing.s)
                moonMenu
                resetButton
            }
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.top, Theme.Spacing.l)
            .padding(.bottom, Theme.Spacing.s)

            if scrolling {
                ScrollView {
                    entryRows
                        .padding(.horizontal, Theme.Spacing.l)
                        .padding(.vertical, Theme.Spacing.s)
                }
                .scrollBounceBehavior(.basedOnSize)
                .accessibilityIdentifier("roundInput.scroll")
                .frame(maxHeight: .infinity)
            } else {
                entryRows
                    .padding(.horizontal, Theme.Spacing.l)
                    .padding(.vertical, Theme.Spacing.s)
            }
            footer
        }
        .background(Theme.cardSurface)
    }

    /// The player rows plus, when the 10♦ rule is on, the "taken by" picker; shared by sheet and inline.
    private var entryRows: some View {
        VStack(spacing: Theme.Spacing.s) {
            ForEach(Array(model.game.players.enumerated()), id: \.element.id) { index, player in
                playerRow(player, index: index)
            }
            if isTenRuleOn {
                tenOfDiamondsSection
            }
        }
    }

    private func tile<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: Theme.Radius.card - 8, style: .continuous)
        return content()
            .padding(.horizontal, Theme.Spacing.m + 2)
            .padding(.vertical, Theme.Spacing.s)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(shape.fill(Theme.cardInset))
            .overlay(shape.strokeBorder(Color.primary.opacity(contrast == .increased ? 0.45 : 0.06), lineWidth: contrast == .increased ? 1.5 : 1))
    }

    // MARK: Header controls

    private var isResetDisabled: Bool { isAllScoresZero && entry.tenOfDiamondsOwnerID == nil }

    @ViewBuilder
    private var resetButton: some View {
        switch presentation {
        case .sheet:
            Button {
                reset()
            } label: {
                Label("Reset", systemImage: "arrow.counterclockwise").labelStyle(.iconOnly)
            }
            .disabled(isResetDisabled)
        case .inline:
            Button {
                reset()
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.subheadline.weight(.semibold))
                    .panelIconButtonLook(isEnabled: !isResetDisabled)
            }
            .buttonStyle(.plain)
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            .disabled(isResetDisabled)
            .accessibilityLabel(Text("Reset"))
        }
    }

    /// Mid-game switch for the shoot-the-moon rule (also in Settings › Game Rules).
    private var moonMenu: some View {
        let pref = model.settings.shootMoonPreference
        return Menu {
            Picker("Shoot the Moon Preference", selection: $model.settings.shootMoonPreference) {
                ForEach(ShootMoonPreference.allCases) { option in
                    Text(option.detailLabel).tag(option)
                }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "moon.fill")
                if !isAccessibilitySize {
                    Text(pref.label).lineLimit(1)
                }
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.moon)
            .padding(.horizontal, 12)
            .frame(minHeight: 34)
            .background(Capsule(style: .continuous).fill(Theme.moon.opacity(contrast == .increased ? 0.24 : 0.14)))
            .frame(minHeight: 44)
            .contentShape(Rectangle())
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        }
        .menuOrder(.fixed)
        .accessibilityLabel(Text("Shoot the Moon Preference"))
        .accessibilityValue(Text(pref.label))
        .accessibilityIdentifier("roundInput.moonMenu")
    }

    // MARK: Footer

    private var footer: some View {
        VStack(spacing: Theme.Spacing.m) {
            progressStrip

            Button {
                submit()
            } label: {
                Text(needsTenOfDiamondsHolder ? "Select who took the 10♦" : (isEditing ? "Save" : "Submit"))
                    .font(.headline.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.roundedRectangle(radius: Theme.Radius.well + 2))
            .tint(Theme.accent)
            .controlSize(.large)
            .keyboardShortcut(.return, modifiers: .command)
            .accessibilityLabel(isEditing ? Text("Save round scores") : Text("Submit round scores"))
            .accessibilityIdentifier("roundInput.submit")
            .disabled(!canSubmit)
        }
        .padding(.horizontal, Theme.Spacing.l)
        .padding(.top, Theme.Spacing.m)
        .padding(.bottom, Theme.Spacing.l)
        .frame(maxWidth: .infinity)
        .background(Theme.cardSurface.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.primary.opacity(contrast == .increased ? 0.5 : 0.10))
                .frame(height: 1)
                .accessibilityHidden(true)
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
        let tint: Color = isOver ? .red : (isDone ? Theme.accent : (isRoundValid ? Theme.moon : Color.secondary))
        let fraction: Double = isRoundValid ? 1 : min(1, max(0, Double(totalPoints) / 26))
        return VStack(spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: isDone ? "checkmark.circle.fill" : (isOver ? "exclamationmark.triangle.fill" : "circle.dashed"))
                Text(progressText)
                    .contentTransition(reduceMotion ? .identity : .numericText())
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .font(.subheadline.weight(.medium))
            .monospacedDigit()
            .foregroundStyle(tint)

            Capsule()
                .fill(Color.primary.opacity(contrast == .increased ? 0.35 : 0.12))
                .frame(height: contrast == .increased ? 8 : 6)
                .overlay(alignment: .leading) {
                    GeometryReader { geo in
                        Capsule()
                            .fill(isOver ? Color.red : (isDone || isRoundValid ? Theme.accent : Theme.accent.opacity(0.75)))
                            .frame(width: max(0, geo.size.width * (isOver ? 1 : fraction)))
                    }
                }
        }
        .animation(reduceMotion ? nil : .default, value: progressText)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(progressText)
        .accessibilityIdentifier("roundInput.progress")
    }

    // MARK: Player row

    /// One design for sheet and inline: [name + total | − value +] over a row of tinted quick actions.
    /// The name block is always name-over-total, so every row lays out alike and the stepper column lines up.
    @ViewBuilder
    private func playerRow(_ player: HeartsGame.Player, index: Int) -> some View {
        let quick = model.settings.quickIncrementPoints
        let remaining = remainingPoints(for: player.id)
        tile {
            // The chips' 44pt hit areas carry ~5pt of padding each, so the row needs no extra spacing.
            VStack(alignment: .leading, spacing: 0) {
                if isAccessibilitySize {
                    VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                        identity(for: player)
                        stepper(for: player)
                    }
                } else {
                    HStack(spacing: Theme.Spacing.s) {
                        identity(for: player)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        stepper(for: player)
                    }
                }
                actions(for: player, quick: quick, remaining: remaining)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(player.name)
        .accessibilityValue(String(format: String(localized: "%d points"), entry.points[player.id] ?? 0))
        .accessibilityIdentifier("roundInput.row.\(index)")
    }

    /// Name (headline) with the cumulative total as quiet secondary text and a crown for the leader(s).
    private func identity(for player: HeartsGame.Player) -> some View {
        let total = model.game.totalPoints(for: player.id, excluding: editingHandID)
        let isLeader = leadingPlayerIDs.contains(player.id)
        return VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(player.name)
                    .font(.headline.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    // At accessibility sizes shrink instead of truncating to "x…" in a narrow pane.
                    .minimumScaleFactor(isAccessibilitySize ? 0.5 : 1)
                tenChip(for: player)
            }
            HStack(spacing: 4) {
                if isLeader {
                    Image(systemName: "crown.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.leader)
                        .accessibilityHidden(true)
                }
                Text(String(format: String(localized: "Total %d"), total))
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(Color.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(String(format: String(localized: "Total %d"), total)))
            .accessibilityValue(Text(isLeader ? String(localized: "Leading") : ""))
            .accessibilityIdentifier("playerTotal.\(player.name)")
        }
    }

    private func actions(for player: HeartsGame.Player, quick: Int, remaining: Int) -> some View {
        let isShooter = entry.moonShooterID(players: model.game.players) == player.id
        let isQueenOwner = entry.queenOwnerID == player.id
        let quickChip = quickChip(for: player, quick: quick, remaining: remaining)
        let remainingChip = remainingChip(for: player, remaining: remaining)
        let queenChip = queenChip(for: player, isSelected: isQueenOwner)
        let moonChip = moonChip(for: player, isSelected: isShooter)
        return Group {
            if isAccessibilitySize {
                Grid(horizontalSpacing: 6, verticalSpacing: 0) {
                    GridRow { quickChip; remainingChip }
                    GridRow { queenChip; moonChip }
                }
            } else {
                HStack(spacing: Theme.Spacing.s) {
                    quickChip
                    remainingChip
                    queenChip
                    moonChip
                }
            }
        }
        .frame(maxWidth: .infinity)
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

    private var tenOfDiamondsSection: some View {
        tile {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("10♦ taken by")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.secondary)
                    .accessibilityAddTraits(.isHeader)
                FlowLayout(spacing: 8) {
                    ForEach(model.game.players) { player in
                        tenOfDiamondsButton(for: player)
                    }
                }
                Text("Tap the player who took the 10♦. They get 10 points subtracted this round.")
                    .font(.footnote)
                    .foregroundStyle(Color.secondary)
            }
        }
    }

    // MARK: Chips

    private func quickChip(for player: HeartsGame.Player, quick: Int, remaining: Int) -> some View {
        Button("+\(quick)") {
            adjustPoints(for: player.id, delta: quick)
        }
        .accessibilityLabel(String(format: String(localized: "Add %d points to %@"), quick, player.name))
        .accessibilityIdentifier("roundInput.quick.\(player.name)")
        .buttonStyle(ActionChipStyle(tint: Theme.accent, selectedForeground: .white, isSelected: false, minWidth: max(tapSize, chipWidth)))
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
        .buttonStyle(ActionChipStyle(tint: Theme.accent, selectedForeground: .white, isSelected: false, minWidth: max(tapSize, chipWidth)))
        .disabled(remaining == 0 || isRoundValid)
    }

    private func queenChip(for player: HeartsGame.Player, isSelected: Bool) -> some View {
        Button("Q♠") {
            addQueenOfSpades(for: player.id)
        }
        .accessibilityLabel(String(format: String(localized: "Queen of spades to %@"), player.name))
        .accessibilityIdentifier("roundInput.queen.\(player.name)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .buttonStyle(ActionChipStyle(tint: Theme.accent, selectedForeground: .white, isSelected: isSelected, minWidth: max(tapSize, chipWidth)))
        .disabled(isRoundValid || entry.queenOwnerID != nil)
    }

    private func moonChip(for player: HeartsGame.Player, isSelected: Bool) -> some View {
        Button {
            applyShootMoonValue(for: player.id)
        } label: {
            Image(systemName: "moon.fill")
        }
        .accessibilityLabel(String(format: String(localized: "Shoot the moon for %@"), player.name))
        .accessibilityIdentifier("roundInput.moon.\(player.name)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .buttonStyle(ActionChipStyle(tint: Theme.moon, selectedForeground: Theme.moonOnFill, isSelected: isSelected, minWidth: max(tapSize, chipWidth)))
        .disabled(isRoundValid)
    }

    /// Display-only "10♦" indicator beside the holder's name.
    @ViewBuilder
    private func tenChip(for player: HeartsGame.Player) -> some View {
        if isTenRuleOn {
            if entry.tenOfDiamondsOwnerID == player.id {
                tenChipLabel
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(String(format: String(localized: "%@ took the 10 of diamonds"), player.name))
                    .accessibilityIdentifier("roundInput.tenBadge.\(player.name)")
            }
        }
    }

    private var tenChipLabel: some View {
        (Text(verbatim: "10") + Text(verbatim: "♦").foregroundColor(.red))
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Color.primary)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 6)
            .frame(minHeight: 24)
            .background(Capsule(style: .continuous).fill(Color.accentColor.opacity(0.18)))
            .overlay(Capsule(style: .continuous).strokeBorder(Color.accentColor, lineWidth: 1.5))
    }

    // MARK: Stepper

    private func stepper(for player: HeartsGame.Player) -> some View {
        let value = entry.points[player.id] ?? 0
        let minusDisabled = isShootTheMoonRound || value == 0
        return HStack(spacing: 6) {
            HoldRepeatButton {
                adjustPoints(for: player.id, delta: -1)
            } label: {
                stepperGlyph("minus", tint: Color.primary, isEnabled: !minusDisabled)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(String(format: String(localized: "Decrease points for %@"), player.name))
            .accessibilityIdentifier("roundInput.decrease.\(player.name)")
            .disabled(minusDisabled)

            valueWell(for: player, value: value)

            HoldRepeatButton {
                adjustPoints(for: player.id, delta: 1)
            } label: {
                stepperGlyph("plus", tint: Theme.accent, isEnabled: !isRoundValid)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(String(format: String(localized: "Increase points for %@"), player.name))
            .accessibilityIdentifier("roundInput.increase.\(player.name)")
            .disabled(isRoundValid)
        }
        // "− N +" in every language: the numbers run left to right, like the native Stepper.
        .pointsStepperLayout()
    }

    private func stepperGlyph(_ symbol: String, tint: Color, isEnabled: Bool) -> some View {
        Image(systemName: symbol)
            .font(.body.weight(.bold))
            .foregroundStyle(isEnabled ? tint : Color.secondary.opacity(0.5))
            .frame(width: tapSize, height: tapSize)
            .background(Circle().fill(isEnabled ? tint.opacity(0.12) : Color.secondary.opacity(0.08)))
            .contentShape(Circle())
            .hoverEffect()
    }

    /// The value in a rounded well; tapping it opens a 0...26 grid to set the exact number in one tap.
    private func valueWell(for player: HeartsGame.Player, value: Int) -> some View {
        let shape = RoundedRectangle(cornerRadius: Theme.Radius.well, style: .continuous)
        return Button {
            valuePickerPlayerID = player.id
        } label: {
            Text("\(value)")
                .font(.system(size: wellFontSize, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundStyle(Color.primary)
                .contentTransition(reduceMotion ? .identity : .numericText(value: Double(value)))
                .frame(width: wellWidth, height: tapSize)
                .background(shape.fill(Theme.cardSurface))
                .overlay(shape.strokeBorder(Color.primary.opacity(contrast == .increased ? 0.6 : 0.14), lineWidth: 1))
                .contentShape(shape)
                .hoverEffect()
        }
        .buttonStyle(.plain)
        .disabled(isShootTheMoonRound)
        .accessibilityLabel(String(format: String(localized: "Set points for %@"), player.name))
        .accessibilityValue(String(format: String(localized: "%d points"), value))
        .accessibilityIdentifier("roundInput.value.\(player.name)")
        .popover(isPresented: Binding(
            get: { valuePickerPlayerID == player.id },
            set: { if !$0 && valuePickerPlayerID == player.id { valuePickerPlayerID = nil } }
        )) {
            PointsGridPicker(current: value) { picked in
                setPoints(for: player.id, to: picked)
                valuePickerPlayerID = nil
            }
            .presentationCompactAdaptation(.popover)
        }
    }

    // MARK: Entry actions (rules live in RoundEntryState / GameViewModel)

    private func adjustPoints(for playerID: UUID, delta: Int) {
        entry.adjustPoints(for: playerID, delta: delta)
    }

    private func setPoints(for playerID: UUID, to value: Int) {
        entry.setPoints(for: playerID, to: value)
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
        entry.isShootTheMoon(players: model.game.players)
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

extension ShootMoonPreference {
    /// Longer menu wording (existing strings, also used by the history summary).
    var detailLabel: String {
        switch self {
        case .add26: return String(localized: "Moon adds 26 to others")
        case .subtract26: return String(localized: "Moon subtracts 26 from shooter")
        }
    }
}

/// 0...26 grid shown from the value well: one tap sets the exact number.
struct PointsGridPicker: View {
    let current: Int
    let onPick: (Int) -> Void
    @Environment(\.colorSchemeContrast) private var contrast

    private let columns = Array(repeating: GridItem(.fixed(44), spacing: 6), count: 6)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(0...RoundEntryState.maxPoints, id: \.self) { value in
                let isCurrent = value == current
                Button {
                    onPick(value)
                } label: {
                    Text("\(value)")
                        .font(.system(.body, design: .rounded).weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(isCurrent ? Color.white : Theme.accent)
                        .frame(width: 44, height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.Radius.well, style: .continuous)
                                .fill(isCurrent ? Theme.accent : Theme.accent.opacity(contrast == .increased ? 0.24 : 0.12))
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isCurrent ? .isSelected : [])
                .accessibilityIdentifier("roundInput.valueOption.\(value)")
            }
        }
        .padding(Theme.Spacing.m)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }
}

/// Tinted capsule (not filled): accent/moon label on a 14% tint, solid when selected, dimmed when disabled.
/// 34pt tall visually inside a 44pt hit area so rows stay compact.
private struct ActionChipStyle: ButtonStyle {
    let tint: Color
    let selectedForeground: Color
    let isSelected: Bool
    let minWidth: CGFloat
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.colorSchemeContrast) private var contrast

    func makeBody(configuration: Configuration) -> some View {
        let foreground: Color = isSelected ? selectedForeground : (isEnabled ? tint : Color.secondary.opacity(0.6))
        let fill: Color = isSelected ? tint : (isEnabled ? tint.opacity(contrast == .increased ? 0.24 : 0.14) : Color.secondary.opacity(0.10))
        return configuration.label
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .allowsTightening(true)
            .foregroundStyle(foreground)
            .padding(.horizontal, ChipMetrics.horizontalPadding)
            .frame(minWidth: minWidth, maxWidth: .infinity, minHeight: 34)
            .background(Capsule(style: .continuous).fill(fill))
            .overlay {
                if contrast == .increased && (isEnabled || isSelected) {
                    Capsule(style: .continuous).strokeBorder(tint, lineWidth: 1.5)
                }
            }
            .opacity(configuration.isPressed ? 0.7 : 1)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
            .contentShape(.hoverEffect, Capsule(style: .continuous))
            .hoverEffect()
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

