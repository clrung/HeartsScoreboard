import SwiftUI

struct GameView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var model: GameViewModel
    @State private var showingRoundInput = false
    @State private var showingSettings = false
    @State private var showingHistory = false
    @State private var showUndoAlert = false
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


    /// - Parameter model: injectable for tests/previews; defaults to the iCloud-synced state.
    init(model: GameViewModel? = nil) {
        _model = State(initialValue: model ?? GameViewModel(initialState: CloudSyncManager.shared.load()))
        // Injected models (tests, screenshot demo) must never see or set the first-run shake hint.
        _hasShownShakeHint = State(initialValue: model != nil || UserDefaults.standard.bool(forKey: "hasShownShakeUndoHint"))
    }

    var body: some View {
        ZStack {
            Theme.feltGradient(for: colorScheme)
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
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: showsResultsOverlay)
        .background(
            ShakeDetectorView(onShake: {
                if model.canUndo { showUndoAlert = true }
            }, refocusToken: shakeRefocusToken)
                .frame(width: 1, height: 1)
                .allowsHitTesting(false)
        )
        .modifier(GamePresentationsModifier(
            model: model,
            showingRoundInput: $showingRoundInput,
            showingSettings: $showingSettings,
            showingHistory: $showingHistory,
            showUndoAlert: $showUndoAlert,
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
            showUndoAlert: showUndoAlert,
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

    private var shakeHintOverlay: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                if #available(iOS 18.0, *) {
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
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.white.opacity(colorScheme == .dark ? 0.45 : 0.7), lineWidth: 1)
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
                .padding(8)
                .background {
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(colorScheme == .dark ? 0.18 : 0.3))
                }
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(Color.white.opacity(colorScheme == .dark ? 0.4 : 0.6), lineWidth: 0.5)
                }
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
                .padding(8)
                .background {
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(colorScheme == .dark ? 0.18 : 0.3))
                }
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(Color.white.opacity(colorScheme == .dark ? 0.4 : 0.6), lineWidth: 0.5)
                }
                .foregroundStyle(.primary)
        }
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
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(.ultraThinMaterial)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Theme.scoreboardCard(for: colorScheme).opacity(colorScheme == .dark ? 0.9 : 0.85))
            )
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
                RoundRailColumn(count: model.game.hands.count)
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
                            .id(hand.id)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .top)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 8)
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: model.game.hands.count)
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
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
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

    /// Deep green for the primary button: white text on it is ~5.9:1 in both appearances
    /// (the dark-mode accent is too light for white text).
    private static let feltButtonGreen = Color(red: 0.10, green: 0.45, blue: 0.20)

    /// Next Round is the prominent full-width action; Undo and a "more" menu (New Game) sit beside it.
    /// Stacks at large text sizes so labels never clip. The split layout has no Next Round (the
    /// round-entry pane is inline), so it just shows the secondary controls.
    private var bottomBar: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                moreMenu
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
                    moreMenu
                    undoButton
                    if usesSplitLayout { Spacer(minLength: 0) }
                }
            }
        }
        .font(.callout)
        .padding(.vertical, 12)
    }

    private var moreMenu: some View {
        Menu {
            Button(role: .destructive) {
                showNewGameAlert = true
            } label: {
                Label("New Game", systemImage: "arrow.counterclockwise")
            }
        } label: {
            Image(systemName: "ellipsis")
                .frame(minWidth: 20, minHeight: 22)
                .modifier(FeltChipLook(isEnabled: !model.game.hands.isEmpty))
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .disabled(model.game.hands.isEmpty)
        .accessibilityLabel(Text("More"))
        .accessibilityHint(Text("Starts a new game with the same players"))
        .accessibilityIdentifier("moreMenu")
    }

    private var undoButton: some View {
        Button {
            showUndoAlert = true
        } label: {
            Image(systemName: "arrow.uturn.backward")
        }
        .buttonStyle(FeltChipButtonStyle())
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
        .accessibilityHint(Text("Enter scores for the next round"))
        .accessibilityIdentifier("nextRoundButton")
    }
}

// MARK: - Body modifier groups (keep GameView.body under the type-checker limit)

/// Undo / new-game alerts and the round-input, settings and history sheets.
private struct GamePresentationsModifier: ViewModifier {
    let model: GameViewModel
    @Binding var showingRoundInput: Bool
    @Binding var showingSettings: Bool
    @Binding var showingHistory: Bool
    @Binding var showUndoAlert: Bool
    @Binding var showNewGameAlert: Bool
    @Binding var undoFeedbackToken: Int
    @Binding var newGameFeedbackToken: Int

    func body(content: Content) -> some View {
        content
            .alert("Undo last round", isPresented: $showUndoAlert) {
                Button("No", role: .cancel) {}
                Button("Yes") {
                    model.removeLastHand()
                    undoFeedbackToken += 1
                }
            } message: {
                Text("Are you sure you would like to undo the last round?")
            }
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
    let showUndoAlert: Bool
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
            .onChange(of: showUndoAlert) { _, isShowing in
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

    func body(content: Content) -> some View {
        content
            // Keyed off the local-add token, not hands.count: a round arriving via iCloud sync stays silent.
            .sensoryFeedback(trigger: model.localRoundToken, roundAddedFeedback)
            .sensoryFeedback(.warning, trigger: undoFeedbackToken)
            .sensoryFeedback(.selection, trigger: newGameFeedbackToken)
            .sensoryFeedback(trigger: model.isGameOver, gameOverFeedback)
            .onChange(of: model.localRoundToken) {
                AccessibilityNotification.Announcement(model.roundAddedAnnouncement).post()
            }
            .onChange(of: model.game.hands.count) { _, newCount in
                guard newCount == 1, !hasShownShakeHint else { return }
                hasShownShakeHint = true
                UserDefaults.standard.set(true, forKey: "hasShownShakeUndoHint")
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    showShakeHint = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                        showShakeHint = false
                    }
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

/// The chip appearance, shared with the "more" Menu (which doesn't take a ButtonStyle reliably).
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
    }
}

#Preview {
    GameView()
}
