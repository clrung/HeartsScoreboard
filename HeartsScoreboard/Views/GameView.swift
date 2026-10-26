import SwiftUI

/// Identifies the round whose edit sheet is open.
struct EditTarget: Identifiable, Equatable {
    let id: UUID
}

/// The transient "Round N undone" toast; a new `id` restarts its auto-dismiss timer.
struct UndoToast: Equatable {
    let id = UUID()
    let message: String
}

struct GameView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var model: GameViewModel
    @State private var showingRoundInput = false
    @State private var showingSettings = false
    @State private var showingHistory = false
    @State private var editTarget: EditTarget?
    @State private var undoToast: UndoToast?
    @State private var showNewGameAlert = false
    @State private var showShakeHint = false
    @State private var shakeRefocusToken = 0
    /// Bumped by confirmed undo / new game so `.sensoryFeedback` fires for those actions only.
    @State private var undoFeedbackToken = 0
    @State private var newGameFeedbackToken = 0
    @State private var hasShownShakeHint: Bool
    /// Compact width: the user closed the game-over card to look at the final scoreboard.
    @State private var resultsDismissed = false
    /// Confetti plays only when the game ends while watching (not for an already-finished game on launch).
    @State private var confettiPlaying = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    /// - Parameter model: injectable for tests/previews; defaults to the iCloud-synced state.
    /// - Parameter initialUndoToast: test hook that shows the undo toast from the first frame.
    init(model: GameViewModel? = nil, initialUndoToast: String? = nil) {
        _undoToast = State(initialValue: initialUndoToast.map { UndoToast(message: $0) })
        _model = State(initialValue: model ?? GameViewModel(initialState: CloudSyncManager.shared.load()))
        // Injected models (tests, screenshot demo) must never see or set the first-run shake hint.
        _hasShownShakeHint = State(initialValue: model != nil || UserDefaults.standard.bool(forKey: "hasShownShakeUndoHint"))
    }

    var body: some View {
        ZStack {
            Theme.feltGradient(for: colorScheme, contrast: contrast)
                .ignoresSafeArea()

            if usesSplitLayout {
                splitLayout
            } else {
                VStack(spacing: 0) {
                    header
                    scoreboard
                    bottomBar
                }
                .padding(.horizontal)
            }

            if showsResultsOverlay {
                resultsOverlay
                    .transition(.opacity)
            }

            if confettiPlaying && !reduceMotion && (usesSplitLayout || showsResultsOverlay) {
                ConfettiView()
                    .ignoresSafeArea()
            }

            if showShakeHint {
                shakeHintOverlay
                    .transition(.opacity)
            }

            if let toast = undoToast {
                undoToastOverlay(toast)
            }

            if model.canRedo && !anySheetPresented {
                redoShortcutButton
            }
        }
        .task(id: undoToast?.id) {
            // Auto-dismiss; VoiceOver users get longer to find the Redo button.
            guard undoToast != nil else { return }
            let seconds: Double = UIAccessibility.isVoiceOverRunning ? 10 : 4
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) { undoToast = nil }
        }
        .onChange(of: model.canRedo) { _, canRedo in
            // A new round, an edit or an iCloud sync invalidates the redo; the toast must not offer it.
            if !canRedo { undoToast = nil }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: showsResultsOverlay)
        .background(
            ShakeDetectorView(onShake: {
                performUndo()
            }, refocusToken: shakeRefocusToken)
                .frame(width: 1, height: 1)
                .allowsHitTesting(false)
        )
        .modifier(GamePresentationsModifier(
            model: model,
            showingRoundInput: $showingRoundInput,
            showingSettings: $showingSettings,
            showingHistory: $showingHistory,
            editTarget: $editTarget,
            showNewGameAlert: $showNewGameAlert,
            undoFeedbackToken: $undoFeedbackToken,
            newGameFeedbackToken: $newGameFeedbackToken
        ))
        .modifier(GameShakeRefocusModifier(
            model: model,
            token: $shakeRefocusToken,
            showingRoundInput: showingRoundInput,
            showingSettings: showingSettings,
            showingHistory: showingHistory,
            showingEdit: editTarget != nil,
            showNewGameAlert: showNewGameAlert
        ))
        .modifier(GameRoundEventsModifier(
            model: model,
            undoFeedbackToken: undoFeedbackToken,
            newGameFeedbackToken: newGameFeedbackToken,
            hasShownShakeHint: $hasShownShakeHint,
            showShakeHint: $showShakeHint
        ))
        .onAppear {
            guard model.persistsToCloud else { return }
            CloudSyncManager.shared.onSyncFromCloud = { [model] state in
                model.applySyncedState(state)
            }
        }
        .onChange(of: model.isGameOver) { _, isOver in
            // A new game (rematch, undo of the final round) re-arms the card for the next finish.
            resultsDismissed = false
            confettiPlaying = isOver
        }
        .onChange(of: usesSplitLayout) { _, isSplit in
            // The inline panel replaces the round-input sheet.
            if isSplit { showingRoundInput = false }
        }
    }

    /// Regular width (unfolded iPhone Duo, iPad): scoreboard and inline round entry side by side.
    private var usesSplitLayout: Bool { horizontalSizeClass == .regular }

    /// Two equal panes with a gap centered on the screen, so no pane's content crosses the
    /// vertical center line (the fold on a partially folded iPhone Duo).
    private var splitLayout: some View {
        VStack(spacing: 0) {
            // Full-width header so both panes start at the same y.
            header
                .padding(.horizontal, 24)

            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    scoreboard
                    bottomBar
                }
                .frame(maxWidth: .infinity)
                .padding(.leading, 24)
                .padding(.trailing, 20)

                roundEntryPane
                    .frame(maxWidth: .infinity)
                    .padding(.leading, 20)
                    .padding(.trailing, 24)
            }
        }
        .frame(maxWidth: 1200)
        .frame(maxWidth: .infinity)
    }

    /// Compact width only; the split layout shows the same card in the right pane instead.
    private var showsResultsOverlay: Bool {
        model.isGameOver && !resultsDismissed && !usesSplitLayout
    }

    private func gameOverCard(dismissible: Bool) -> some View {
        GameOverView(
            standings: model.standings,
            onRematch: {
                model.rematch()
                newGameFeedbackToken += 1
            },
            onViewHistory: {
                // Hide the card first so it isn't sitting under the sheet when the user comes back.
                if dismissible { resultsDismissed = true }
                showingHistory = true
            },
            onClose: dismissible ? { resultsDismissed = true } : nil,
            completedGame: CompletedGame(game: model.game, settings: model.settings)
        )
    }

    private var resultsOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture { resultsDismissed = true }
                .accessibilityHidden(true)
            gameOverCard(dismissible: true)
                .frame(maxWidth: 440)
                .padding(.horizontal, 20)
                .padding(.vertical, 40)
        }
        .accessibilityAddTraits(.isModal)
    }

    @ViewBuilder
    private var roundEntryPane: some View {
        VStack(spacing: 0) {
            if model.isGameOver {
                gameOverCard(dismissible: false)
                    .frame(maxHeight: .infinity)
            } else {
                RoundInputView(model: model, presentation: .inline)
                    .background(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(Color(.systemGroupedBackground))
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.45 : 0.20), radius: 18, x: 0, y: 10)
                    .frame(maxHeight: .infinity)
            }
        }
        .padding(.top, 8) // matches the scoreboard card's top inset
        .padding(.bottom, 12)
    }

    @ScaledMetric(relativeTo: .caption) private var dealerSlotHeight: CGFloat = 25

    private var dealerIndex: Int { model.currentDealerIndex }

    private var dealerBadge: some View {
        Text("D")
            .font(.caption.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 6 * dealerBadgeScale)
            .padding(.vertical, 4 * dealerBadgeScale)
            .background {
                Capsule()
                    .fill(Theme.dealerBadgeGradient(for: colorScheme))
            }
            .overlay {
                Capsule()
                    .strokeBorder(Color.white.opacity(colorScheme == .dark ? 0.35 : 0.5), lineWidth: 1)
            }
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.4 : 0.15), radius: 2, x: 0, y: 1)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Dealer"))
    }

    /// The hint's blurred material is unreadable over the felt without transparency; use a solid card then.
    private var hintNeedsSolidBackground: Bool { reduceTransparency || contrast == .increased }

    private var shakeHintOverlay: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                if #available(iOS 18.0, *), !reduceMotion {
                    Image(systemName: "iphone.radiowaves.left.and.right")
                        .font(.system(size: 28, weight: .semibold))
                        .symbolEffect(.bounce, options: .repeating)
                        .accessibilityHidden(true)
                } else {
                    Image(systemName: "iphone.radiowaves.left.and.right")
                        .font(.system(size: 28, weight: .semibold))
                        .accessibilityHidden(true)
                }

                Text(String(localized: "Shake to undo the last round!"))
                    .font(.headline.weight(.semibold))
                    .multilineTextAlignment(.leading)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(hintNeedsSolidBackground ? AnyShapeStyle(Color(.systemBackground)) : AnyShapeStyle(.ultraThinMaterial))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(
                                hintNeedsSolidBackground ? Color.primary.opacity(0.7) : Color.white.opacity(colorScheme == .dark ? 0.45 : 0.7),
                                lineWidth: hintNeedsSolidBackground ? 1.5 : 1
                            )
                    )
            )
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, 120)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(String(localized: "Shake to undo the last round!")))
    }

    private var dealerBadgeScale: CGFloat {
        switch dynamicTypeSize {
        case .xSmall, .small, .medium:
            return 1.3
        case .large, .xLarge:
            return 1.5
        case .xxLarge:
            return 1.7
        case .xxxLarge, .accessibility1:
            return 1.9
        default:
            return 2.1
        }
    }

    private var historyButton: some View {
        Button {
            showingHistory = true
        } label: {
            Image(systemName: "clock.arrow.circlepath")
                .font(.title2.weight(.semibold))
                .feltIconButtonLook()
        }
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .accessibilityLabel(Text("History"))
        .accessibilityIdentifier("historyButton")
    }

    private var settingsButton: some View {
        Button {
            showingSettings = true
        } label: {
            Image(systemName: "gearshape.fill")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.primary)
                .feltIconButtonLook()
        }
        .keyboardShortcut(",", modifiers: .command)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .accessibilityLabel(Text("Settings"))
        .accessibilityIdentifier("settingsButton")
    }

    /// History and Settings flank a compact status line (pass direction, round, target).
    private var header: some View {
        HStack(spacing: 8) {
            historyButton
            statusLine
                .frame(maxWidth: .infinity)
            settingsButton
        }
        .padding(.vertical, 12)
    }

    private var currentDirection: PassDirection {
        let phase = model.passDirectionPhaseIndex(forCompletedHandCount: model.game.hands.count)
        return PassDirection.forPhase(phase, playerCount: model.game.players.count)
    }

    private var roundText: some View {
        Text(String(format: String(localized: "Round %d"), model.game.hands.count + 1))
            .fontWeight(.semibold)
            .lineLimit(1)
    }

    private var targetText: some View {
        Text(String(format: String(localized: "to %d"), model.settings.endingScore))
            .lineLimit(1)
            .accessibilityLabel(Text(String(format: String(localized: "Game to: %d"), model.settings.endingScore)))
    }

    @ViewBuilder
    private var statusLine: some View {
        if model.isGameOver {
            Text(model.statusText)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
        } else {
            // One line when it fits; stacked at large text sizes instead of truncating.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    PassDirectionChip(direction: currentDirection)
                    roundText
                    targetText
                }
                VStack(spacing: 4) {
                    PassDirectionChip(direction: currentDirection)
                    HStack(spacing: 8) {
                        roundText
                        targetText
                    }
                }
            }
            .font(.subheadline)
            .foregroundStyle(Color.white)
            .accessibilityElement(children: .contain)
        }
    }

    private var scoreboard: some View {
        FeltCardSurface(cornerRadius: 24, colorScheme: colorScheme)
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(contrast == .increased ? Color.primary.opacity(0.6) : Color.white.opacity(colorScheme == .dark ? 0.20 : 0.35), lineWidth: contrast == .increased ? 2 : 1)
            )
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.45 : 0.20), radius: 18, x: 0, y: 10)
            .overlay(alignment: .top) {
                scoreboardContent
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .padding(.top, 8)
    }

    /// 6 players in the side-by-side pane: names get truncated to ~3 characters, so show initials instead.
    private var usesInitialHeaders: Bool { usesSplitLayout && model.game.players.count > 5 }

    private var headerLabels: [String] { HeartsGame.headerLabels(for: model.game.players.map(\.name)) }

    private var scoreboardContent: some View {
        VStack(spacing: 12) {
            VStack(spacing: 8) {
                HStack(spacing: 0) {
                    Color.clear.frame(width: RoundRail.width, height: 1)
                    ForEach(Array(model.game.players.enumerated()), id: \.element.id) { index, player in
                        let headerLabel = usesInitialHeaders ? headerLabels[index] : player.name
                        VStack(spacing: 6) {
                            ZStack {
                                if index == dealerIndex {
                                    dealerBadge
                                }
                            }
                            .frame(minHeight: dealerSlotHeight)
                            Text(headerLabel)
                                .accessibilityLabel(player.name)
                                .font((usesSplitLayout && model.game.players.count > 4 ? Font.subheadline : Font.headline).weight(.semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .truncationMode(.tail)
                                .accessibilityAddTraits(.isHeader)
                                .padding(.vertical, 4)
                                .padding(.horizontal, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(
                                            Color.white.opacity(colorScheme == .dark ? (contrast == .increased ? 0.22 : 0.10) : (contrast == .increased ? 0.5 : 0.26))
                                        )
                                )
                                .frame(maxWidth: .infinity)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(maxWidth: .infinity)

                let leaders = model.leadingPlayerIDs
                HStack(alignment: .top, spacing: 0) {
                    Color.clear.frame(width: RoundRail.width, height: 1)
                    ForEach(model.game.players) { player in
                        PlayerTotalBadge(
                            total: model.game.totalPoints(for: player.id),
                            isLeader: leaders.contains(player.id),
                            colorScheme: colorScheme,
                            progress: model.progress(for: player.id),
                            pointsToGo: model.pointsToGo(for: player.id)
                        )
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.black.opacity(colorScheme == .dark ? 0.14 : (contrast == .increased ? 0.14 : 0.06)))
            )

            ScrollViewReader { proxy in
                scoresScroll(proxy: proxy)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.vertical, 6)
        .padding(.horizontal, 6)
        .dynamicTypeSize(...maxScoreboardTypeSize)
    }

    /// One column per player can't hold accessibility-size totals once 5-6 players share a phone-width
    /// card (columns overflowed and clipped), so crowded boards stop growing at a size that still fits.
    private var maxScoreboardTypeSize: DynamicTypeSize {
        let count = model.game.players.count
        if count <= 4 { return .accessibility2 }
        return usesSplitLayout ? .large : .xxxLarge
    }

    private func scoresScroll(proxy: ScrollViewProxy) -> some View {
        ScrollView {
            HStack(alignment: .top, spacing: 0) {
                RoundRailColumn(count: model.game.hands.count, onSelect: { index in
                    editTarget = EditTarget(id: model.game.hands[index].id)
                })
                    .frame(width: RoundRail.width)
                ForEach(model.game.players) { player in
                    VStack(spacing: 8) {
                        ForEach(Array(model.game.hands.enumerated()), id: \.element.id) { index, hand in
                            let score = hand.pointsByPlayerID[player.id] ?? 0
                            let isEvenRow = index.isMultiple(of: 2)
                            let isMoon = model.game.isMoonHand(hand, for: player.id)
                            ScoreCellContent(
                                score: score,
                                isMoon: isMoon,
                                moonBonus: model.game.moonCellTenOfDiamondsBonus(hand, for: player.id),
                                emphasize: score == 26 && !isMoon
                            )
                            .modifier(ScoreCellFrame(hasTenOfDiamonds: hand.tenOfDiamondsPlayerID == player.id))
                            .accessibilityLabel(cellAccessibilityLabel(
                                round: index + 1, playerName: player.name, score: score,
                                isMoon: isMoon, tookTenOfDiamonds: hand.tenOfDiamondsPlayerID == player.id
                            ))
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(
                                        score == 26 && !isMoon
                                        ? Color.orange.opacity(colorScheme == .dark ? 0.35 : 0.3)
                                        : (isEvenRow
                                         ? Color.white.opacity(colorScheme == .dark ? (contrast == .increased ? 0.25 : 0.15) : (contrast == .increased ? 0.6 : 0.35))
                                         : Color.white.opacity(colorScheme == .dark ? (contrast == .increased ? 0.4 : 0.3) : (contrast == .increased ? 0.9 : 0.7))
                                        )
                                    )
                            )
                            .contentShape(Rectangle())
                            .onTapGesture { editTarget = EditTarget(id: hand.id) }
                            .accessibilityAddTraits(.isButton)
                            .accessibilityHint(Text("Edit this round"))
                            .id(hand.id)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .top)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 8)
            .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.85), value: model.game.hands.count)
        }
        .frame(maxHeight: .infinity)
        .overlay {
            if model.game.hands.isEmpty {
                Text("No rounds yet")
                    .font(.subheadline)
                    .foregroundStyle(Color.secondary)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("emptyRoundsLabel")
            }
        }
        .scrollIndicators(.visible)
        .onChange(of: model.game.hands.count) {
            withAnimation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.85)) {
                if let lastHand = model.game.hands.last {
                    proxy.scrollTo(lastHand.id, anchor: .bottom)
                }
            }
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

    /// Content height shared by the three bottom-bar buttons so they render at one height; scales with
    /// the bar's callout text so the chips keep matching Next Round at every Dynamic Type size.
    @ScaledMetric(relativeTo: .callout) private var barContentHeight: CGFloat = 35

    /// Deep green for the primary button: white text on it is ~5.9:1 in both appearances
    /// (the dark-mode accent is too light for white text).
    private static let feltButtonGreen = Color(red: 0.10, green: 0.45, blue: 0.20)

    /// Next Round is the prominent full-width action; Undo and a New Game button sit beside it.
    /// Stacks at large text sizes so labels never clip. The split layout has no Next Round (the
    /// round-entry pane is inline), so it just shows the secondary controls.
    private var bottomBar: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                newGameButton
                undoButton
                if !usesSplitLayout {
                    nextRoundButton
                        .frame(maxWidth: .infinity)
                } else {
                    Spacer(minLength: 0)
                }
            }
            VStack(spacing: 8) {
                if !usesSplitLayout {
                    nextRoundButton
                        .frame(maxWidth: .infinity)
                }
                HStack(spacing: 10) {
                    newGameButton
                    undoButton
                    if usesSplitLayout { Spacer(minLength: 0) }
                }
            }
        }
        .font(.callout)
        .padding(.vertical, 12)
    }

    /// Starts a new game with the same players (after the confirmation alert).
    private var newGameButton: some View {
        Button {
            showNewGameAlert = true
        } label: {
            Image(systemName: "plus.circle")
                .frame(minWidth: 20, minHeight: barContentHeight)
        }
        .buttonStyle(FeltChipButtonStyle())
        .disabled(model.game.hands.isEmpty)
        .accessibilityLabel(Text("New Game"))
        .accessibilityHint(Text("Starts a new game with the same players"))
        .accessibilityIdentifier("newGameButton")
    }

    /// Undo with no confirmation (button and shake share this); offers Redo in a toast instead.
    private func performUndo() {
        guard model.undoLastHand() != nil else { return }
        undoFeedbackToken += 1
        let round = model.game.hands.count + 1
        Announcer.post(GameViewModel.undoneAnnouncement(round: round))
        withAnimation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.85)) {
            undoToast = UndoToast(message: GameViewModel.undoneMessage(round: round))
        }
    }

    /// True while a sheet or alert covers the board; keyboard shortcuts must not undo/redo rounds then
    /// (⌘Z belongs to a text field in Settings, for instance).
    private var anySheetPresented: Bool {
        showingRoundInput || showingSettings || showingHistory || editTarget != nil || showNewGameAlert
    }

    private func performRedo() {
        guard model.redo() != nil else { return }
        undoFeedbackToken += 1
        Announcer.post(GameViewModel.restoredAnnouncement(round: model.game.hands.count))
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) { undoToast = nil }
    }

    /// Bottom-aligned toast just above the bottom bar. In the split layout it stays inside the left pane
    /// so nothing crosses the center fold.
    private func undoToastOverlay(_ toast: UndoToast) -> some View {
        HStack(spacing: 0) {
            UndoToastView(message: toast.message, onRedo: performRedo)
                .frame(maxWidth: .infinity)
                .padding(.leading, usesSplitLayout ? 24 : 0)
                .padding(.trailing, usesSplitLayout ? 20 : 0)
            if usesSplitLayout {
                Color.clear.frame(maxWidth: .infinity, maxHeight: 0).allowsHitTesting(false)
            }
        }
        .padding(.horizontal, usesSplitLayout ? 0 : 16)
        .frame(maxWidth: usesSplitLayout ? 1200 : .infinity)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .padding(.bottom, 76)
        .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
    }

    /// Redo is only a button inside the short-lived toast, so keyboard users get ⇧⌘Z on this invisible
    /// one for as long as a redo is available (it shows in the ⌘-hold shortcut list as "Redo").
    private var redoShortcutButton: some View {
        Button("Redo") { performRedo() }
            .keyboardShortcut("z", modifiers: [.command, .shift])
            .frame(width: 0, height: 0)
            .opacity(0)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private var undoButton: some View {
        Button {
            performUndo()
        } label: {
            Image(systemName: "arrow.uturn.backward")
                .frame(minHeight: barContentHeight)
        }
        .buttonStyle(FeltChipButtonStyle())
        .keyboardShortcut("z", modifiers: .command)
        .disabled(!model.canUndo)
        .accessibilityLabel(Text("Undo Round"))
        .accessibilityIdentifier("undoButton")
    }

    @ViewBuilder
    private var nextRoundButton: some View {
        if model.isGameOver {
            // Next Round is dead once the game ends; bring the result card back instead.
            Button {
                resultsDismissed = false
            } label: {
                Label("Results", systemImage: "trophy.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(Self.feltButtonGreen)
            .overlay { contrastOutline }
            .accessibilityIdentifier("resultsButton")
        } else {
            roundEntryButton
        }
    }

    private var roundEntryButton: some View {
        Button {
            showingRoundInput = true
        } label: {
            Label("Next Round", systemImage: "arrow.right.circle.fill")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(Self.feltButtonGreen)
        .overlay { contrastOutline }
        .keyboardShortcut("n", modifiers: .command)
        .accessibilityHint(Text("Enter scores for the next round"))
        .accessibilityIdentifier("nextRoundButton")
    }

    /// Increase Contrast darkens the felt, so the green prominent button needs an edge to stand out.
    @ViewBuilder private var contrastOutline: some View {
        if contrast == .increased {
            Capsule().strokeBorder(.white, lineWidth: 2).allowsHitTesting(false)
        }
    }
}

// MARK: - Body modifier groups (keep GameView.body under the type-checker limit)

/// The new-game alert and the round-input, edit-round, settings and history sheets.
private struct GamePresentationsModifier: ViewModifier {
    let model: GameViewModel
    @Binding var showingRoundInput: Bool
    @Binding var showingSettings: Bool
    @Binding var showingHistory: Bool
    @Binding var editTarget: EditTarget?
    @Binding var showNewGameAlert: Bool
    @Binding var undoFeedbackToken: Int
    @Binding var newGameFeedbackToken: Int

    func body(content: Content) -> some View {
        content
            .alert("New Game", isPresented: $showNewGameAlert) {
                Button("No", role: .cancel) {}
                Button("Yes") {
                    model.newGame()
                    newGameFeedbackToken += 1
                }
            } message: {
                Text("Are you sure? This will clear all round scores.")
            }
            .sheet(isPresented: $showingRoundInput) {
                RoundInputView(model: model)
            }
            // A sheet in the split layout too, so the inline pane keeps entering the next round.
            .sheet(item: $editTarget) { target in
                RoundInputView(model: model, editingHandID: target.id)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(model: model)
            }
            .sheet(isPresented: $showingHistory) {
                HistoryView(model: model)
            }
    }
}

/// Bumps the shake detector's refocus token whenever something that may have stolen first responder
/// (a sheet, an alert, backgrounding) goes away; also persists settings when that sheet closes.
private struct GameShakeRefocusModifier: ViewModifier {
    let model: GameViewModel
    @Binding var token: Int
    let showingRoundInput: Bool
    let showingSettings: Bool
    let showingHistory: Bool
    let showingEdit: Bool
    let showNewGameAlert: Bool
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            .onChange(of: showingRoundInput) { _, isShowing in
                if !isShowing { token += 1 }
            }
            .onChange(of: showingHistory) { _, isShowing in
                if !isShowing { token += 1 }
            }
            .onChange(of: showingEdit) { _, isShowing in
                if !isShowing { token += 1 }
            }
            .onChange(of: showNewGameAlert) { _, isShowing in
                if !isShowing { token += 1 }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { token += 1 }
            }
            .onChange(of: showingSettings) { _, isShowing in
                if !isShowing { token += 1 }
                if !isShowing { model.persistToCloud() }
            }
    }
}

/// Haptics, the VoiceOver round announcement, and the first-round shake hint.
private struct GameRoundEventsModifier: ViewModifier {
    let model: GameViewModel
    let undoFeedbackToken: Int
    let newGameFeedbackToken: Int
    @Binding var hasShownShakeHint: Bool
    @Binding var showShakeHint: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            // Keyed off the local-add token, not hands.count: a round arriving via iCloud sync stays silent.
            .sensoryFeedback(trigger: model.localRoundToken, roundAddedFeedback)
            .sensoryFeedback(.warning, trigger: undoFeedbackToken)
            .sensoryFeedback(.selection, trigger: newGameFeedbackToken)
            .sensoryFeedback(trigger: model.isGameOver, gameOverFeedback)
            .onChange(of: model.localRoundToken) { roundAdded() }
    }

    /// One announcement per locally added round. The first-run shake hint rides along in it when
    /// VoiceOver is on (a timed overlay is too short to find and read); otherwise it is shown briefly.
    private func roundAdded() {
        let isFirstRound = model.game.hands.count == 1 && !hasShownShakeHint
        let voiceOver = UIAccessibility.isVoiceOverRunning
        if isFirstRound {
            hasShownShakeHint = true
            UserDefaults.standard.set(true, forKey: "hasShownShakeUndoHint")
        }
        Announcer.post(model.roundAddedAnnouncement(includingShakeHint: isFirstRound && voiceOver))
        guard isFirstRound, !voiceOver else { return }
        withAnimation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.8)) {
            showShakeHint = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.85)) {
                showShakeHint = false
            }
        }
    }

    /// A round that ends the game gets the heavier game-over haptic instead.
    private func roundAddedFeedback(old: Int, new: Int) -> SensoryFeedback? {
        model.isGameOver ? nil : .success
    }

    private func gameOverFeedback(old: Bool, new: Bool) -> SensoryFeedback? {
        new && !old ? .impact(weight: .heavy) : nil
    }
}

/// Secondary button on the green felt: opaque system-background chip with an accent label
/// (about 5.6:1 in light, 6.5:1 in dark), so it stays legible where a translucent green
/// `.bordered` button would wash out. Disabled state dims the whole chip.
private struct FeltChipButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .modifier(FeltChipLook(isEnabled: isEnabled, isPressed: configuration.isPressed))
    }
}

/// The chip appearance, used by `FeltChipButtonStyle`.
private struct FeltChipLook: ViewModifier {
    let isEnabled: Bool
    var isPressed = false
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        content
            .foregroundStyle(Theme.accent)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Capsule(style: .continuous).fill(Color(.systemBackground)))
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(Theme.accent.opacity(contrast == .increased ? 1 : 0.35), lineWidth: contrast == .increased ? 2 : 1)
            )
            .opacity(isEnabled ? (isPressed ? 0.7 : 1) : 0.45)
            .contentShape(.hoverEffect, Capsule(style: .continuous))
            .hoverEffect()
    }
}

#Preview {
    GameView()
}
