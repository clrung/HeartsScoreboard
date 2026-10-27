import SwiftUI
import UIKit

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
    /// The inline panel's pending round, lifted here so the scoreboard's pending row can show it live.
    @State private var inlineEntry = RoundEntryState()
    @State private var inlineKeyboard: RoundEntryKeyboard
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
    /// - Parameter initialPending / initialKeyboard: test hooks for snapshots (a half-entered round, a selected row).
    init(model: GameViewModel? = nil, initialUndoToast: String? = nil,
         initialPending: RoundEntryState? = nil, initialKeyboard: RoundEntryKeyboard = RoundEntryKeyboard()) {
        _inlineEntry = State(initialValue: initialPending ?? RoundEntryState())
        _inlineKeyboard = State(initialValue: initialKeyboard)
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
                    compactScoreboard
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

            if let toast = undoToast, !usesSplitLayout {
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
            }, onKey: { handleInlineKey($0) }, refocusToken: shakeRefocusToken)
                .frame(width: 1, height: 1)
                .allowsHitTesting(false)
        )
        .background(WindowAppearanceApplier(style: model.settings.appearance.userInterfaceStyle).frame(width: 1, height: 1).allowsHitTesting(false))
        #if DEBUG
        .overlay(BoardStyleProbe().frame(width: 1, height: 1).allowsHitTesting(false))
        #endif
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
        .onChange(of: model.entryResetKey) {
            // Submit, undo/redo, new game and iCloud sync all change the rounds or players: drop the pending values.
            inlineEntry.reset(players: model.game.players)
        }
        .onChange(of: usesSplitLayout) { _, isSplit in
            // The inline panel replaces the round-input sheet.
            if isSplit { showingRoundInput = false }
        }
    }

    /// Regular width (unfolded iPhone Duo, iPad): scoreboard and inline round entry side by side.
    private var usesSplitLayout: Bool { horizontalSizeClass == .regular }

    /// Available width (pt) from which the scoreboard gets the larger share (iPad landscape).
    private static let wideSplitThreshold: CGFloat = 1100
    private static let maxSplitWidth: CGFloat = 1480

    /// Both cards sit top-aligned under a full-width header and hug their content. From 1100pt available
    /// width the scoreboard gets ~56%; below that the panes are equal with a gap centered on the screen,
    /// so no pane's content crosses the vertical center line (the fold on a partially folded iPhone Duo).
    private var splitLayout: some View {
        GeometryReader { geo in
            let side = Theme.Spacing.xl
            let wide = geo.size.width >= Self.wideSplitThreshold
            let container = min(geo.size.width, Self.maxSplitWidth)
            let gap: CGFloat = wide ? Theme.Spacing.xl : 40
            let inner = container - 2 * side - gap
            let leftWidth = wide ? inner * 0.56 : inner / 2
            let rightWidth = inner - leftWidth
            VStack(spacing: 0) {
                // Full-width header so both panes start at the same y.
                header
                    .padding(.horizontal, side)

                HStack(alignment: .top, spacing: gap) {
                    splitScoreboardPane(width: leftWidth)
                        .frame(width: leftWidth)
                    roundEntryPane
                        .frame(width: rightWidth)
                }
                .padding(.horizontal, side)
            }
            .frame(width: container)
            .frame(maxWidth: .infinity)
        }
    }

    private func splitScoreboardPane(width: CGFloat) -> some View {
        ScoreboardCard(model: model, width: width, isSplit: true, pendingEntry: inlineEntry, onEdit: { editTarget = EditTarget(id: $0) })
            .frame(maxHeight: .infinity, alignment: .top)
            .padding(.top, Theme.Spacing.s)
            .padding(.bottom, Theme.Spacing.l)
            .overlay(alignment: .bottom) {
                if let toast = undoToast {
                    UndoToastView(message: toast.message, onRedo: performRedo)
                        .padding(.bottom, Theme.Spacing.xl)
                        .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                }
            }
    }

    /// iPhone-width board: the card fills the height between the header and the bottom bar.
    private var compactScoreboard: some View {
        GeometryReader { geo in
            ScoreboardCard(model: model, width: geo.size.width, isSplit: false, onEdit: { editTarget = EditTarget(id: $0) })
                .frame(maxHeight: .infinity)
        }
        .padding(.top, Theme.Spacing.s)
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
                    .frame(maxHeight: .infinity, alignment: .top)
            } else {
                entryCard
                    .frame(maxHeight: .infinity, alignment: .top)
            }
        }
        .padding(.top, Theme.Spacing.s) // matches the scoreboard card's top inset
        .padding(.bottom, Theme.Spacing.l)
    }

    /// Same card family as the scoreboard (surface, radius, hairline, elevation); hugs its content.
    private var entryCard: some View {
        let shape = RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
        let shadow = Theme.Elevation.card(for: colorScheme)
        return RoundInputView(model: model, presentation: .inline, inlineEntry: $inlineEntry,
                              inlineKeyboard: $inlineKeyboard, keyboardEnabled: !anySheetPresented)
            .background(Theme.cardSurface)
            .clipShape(shape)
            .overlay(
                shape.strokeBorder(
                    contrast == .increased ? Color.primary.opacity(0.6) : Color.primary.opacity(colorScheme == .dark ? 0.14 : 0.07),
                    lineWidth: contrast == .increased ? 2 : 1
                )
            )
            .shadow(color: shadow.color, radius: shadow.radius, x: 0, y: shadow.y)
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
                .feltIconButtonLook()
        }
        .keyboardShortcut(",", modifiers: .command)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .accessibilityLabel(Text("Settings"))
        .accessibilityIdentifier("settingsButton")
    }

    /// Split header: Undo beside History; New Game beside Settings (they replace the bottom bar).
    private var headerUndoButton: some View {
        Button {
            performUndo()
        } label: {
            Image(systemName: "arrow.uturn.backward")
                .font(.title2.weight(.semibold))
                .feltIconButtonLook()
        }
        .keyboardShortcut("z", modifiers: .command)
        .disabled(!model.canUndo)
        .opacity(model.canUndo ? 1 : 0.45)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .accessibilityLabel(Text("Undo Round"))
        .accessibilityIdentifier("undoButton")
    }

    private var headerNewGameButton: some View {
        Button {
            showNewGameAlert = true
        } label: {
            Image(systemName: "plus.circle")
                .font(.title2.weight(.semibold))
                .feltIconButtonLook()
        }
        .keyboardShortcut("n", modifiers: .command)
        .disabled(model.game.hands.isEmpty)
        .opacity(model.game.hands.isEmpty ? 0.45 : 1)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .accessibilityLabel(Text("New Game"))
        .accessibilityHint(Text("Starts a new game with the same players"))
        .accessibilityIdentifier("newGameButton")
    }

    /// Compact: History and Settings flank a status line (pass direction, round, target).
    /// Split: History · Undo | status | New Game · Settings.
    @ViewBuilder
    private var header: some View {
        if usesSplitLayout {
            HStack(spacing: Theme.Spacing.s) {
                HStack(spacing: Theme.Spacing.s) {
                    historyButton
                    headerUndoButton
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                statusLine
                HStack(spacing: Theme.Spacing.s) {
                    headerNewGameButton
                    settingsButton
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.vertical, Theme.Spacing.m)
        } else {
            HStack(spacing: Theme.Spacing.s) {
                historyButton
                statusLine
                    .frame(maxWidth: .infinity)
                settingsButton
            }
            .padding(.vertical, Theme.Spacing.m)
        }
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

    /// Deep green for the primary button: white text on it is ~5.9:1 in both appearances
    /// (the dark-mode accent is too light for white text).
    private static let feltButtonGreen = Color(red: 0.10, green: 0.45, blue: 0.20)

    /// Compact width only (the split layout has these actions in the header and the entry panel inline).
    /// Next Round is the prominent full-width action; Undo and a New Game button sit beside it.
    /// Stacks at large text sizes so labels never clip.
    private var bottomBar: some View {
        ViewThatFits(in: .horizontal) {
            // The chips stretch (maxHeight: .infinity inside FeltChipLook) to the row's ideal height, which
            // Next Round sets, so all three always share one height at any Dynamic Type size.
            HStack(spacing: 10) {
                newGameButton
                undoButton
                nextRoundButton
                    .frame(maxWidth: .infinity)
            }
            .fixedSize(horizontal: false, vertical: true)
            VStack(spacing: 8) {
                nextRoundButton
                    .frame(maxWidth: .infinity)
                HStack(spacing: 10) {
                    newGameButton
                    undoButton
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
                .frame(minWidth: 20)
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

    /// Hardware keys for the inline round-entry panel (the shake detector is first responder, so keys land here).
    /// Ignored in the compact layout, over any sheet/alert, and once the game is over.
    private func handleInlineKey(_ key: UIKey) -> Bool {
        guard usesSplitLayout, !anySheetPresented, !model.isGameOver,
              let command = RoundEntryKeyboard.command(for: key) else { return false }
        inlineKeyboard.apply(command, to: &inlineEntry, players: model.game.players,
                             preference: model.settings.shootMoonPreference)
        return true
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

    /// Bottom-aligned toast just above the bottom bar (compact width; the split layout shows it inside
    /// the scoreboard pane so nothing crosses the center fold).
    private func undoToastOverlay(_ toast: UndoToast) -> some View {
        UndoToastView(message: toast.message, onRedo: performRedo)
            .padding(.horizontal, 16)
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
            Label("Next Round", systemImage: DirectionalUI.nextRoundSymbol)
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

/// Secondary button on the green felt: opaque chip, so it stays legible where a translucent green
/// `.bordered` button would wash out. Light: system-background fill with an accent label (about 5.6:1).
/// Dark: a lifted felt green with a white label (about 6:1), because a near-black fill vanished on the
/// dark felt. Disabled state dims the whole chip.
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
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .foregroundStyle(Theme.feltChipLabel(for: colorScheme))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            // 44pt tap target; stretches to a sibling's height when the parent fixes the row height.
            .frame(minHeight: 44, maxHeight: .infinity)
            .background(Capsule(style: .continuous).fill(Theme.feltChipFill(for: colorScheme)))
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(Theme.feltChipBorder(for: colorScheme, increasedContrast: contrast == .increased),
                                  lineWidth: contrast == .increased ? 2 : 1)
            )
            .opacity(isEnabled ? (isPressed ? 0.7 : 1) : 0.45)
            .contentShape(.hoverEffect, Capsule(style: .continuous))
            .hoverEffect()
    }
}

#Preview {
    GameView()
}
