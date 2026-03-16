import SwiftUI

struct GameView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var model = GameViewModel(initialState: CloudSyncManager.shared.load())
    @State private var showingRoundInput = false
    @State private var showingSettings = false
    @State private var showingHistory = false
    @State private var showUndoAlert = false
    @State private var showNewGameAlert = false
    @State private var showShakeHint = false
    @State private var hasShownShakeHint = UserDefaults.standard.bool(forKey: "hasShownShakeUndoHint")

    var body: some View {
        ZStack {
            backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                scoreboard
                bottomBar
            }
            .padding(.horizontal)

            if showShakeHint {
                shakeHintOverlay
                    .transition(.opacity)
            }
        }
        .background(
            ShakeDetectorView {
                if !model.game.hands.isEmpty { showUndoAlert = true }
            }
                .frame(width: 1, height: 1)
                .allowsHitTesting(false)
        )
        .alert("Undo last round", isPresented: $showUndoAlert) {
            Button("No", role: .cancel) {}
            Button("Yes") {
                model.removeLastHand()
            }
        } message: {
            Text("Are you sure you would like to undo the last round?")
        }
        .alert("New Game", isPresented: $showNewGameAlert) {
            Button("No", role: .cancel) {}
            Button("Yes") {
                model.newGame()
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
        .onAppear {
            CloudSyncManager.shared.onSyncFromCloud = { [model] state in
                model.applySyncedState(state)
            }
        }
        .onChange(of: showingSettings) { _, isShowing in
            if !isShowing { model.persistToCloud() }
        }
        .onChange(of: model.game.hands.count) { _, newCount in
            guard newCount == 1, !hasShownShakeHint else { return }
            hasShownShakeHint = true
            UserDefaults.standard.set(true, forKey: "hasShownShakeUndoHint")
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                showShakeHint = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                    showShakeHint = false
                }
            }
        }
    }

    private var dealerIndex: Int { model.currentDealerIndex }

    private var dealerBadge: some View {
        Text("D")
            .font(.caption.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 6 * dealerBadgeScale)
            .padding(.vertical, 4 * dealerBadgeScale)
            .background {
                Capsule()
                    .fill(dealerBadgeGradient)
            }
            .overlay {
                Capsule()
                    .strokeBorder(Color.white.opacity(colorScheme == .dark ? 0.35 : 0.5), lineWidth: 1)
            }
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.4 : 0.15), radius: 2, x: 0, y: 1)
    }

    private var shakeHintOverlay: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                if #available(iOS 18.0, *) {
                    Image(systemName: "iphone.radiowaves.left.and.right")
                        .font(.system(size: 28, weight: .semibold))
                        .symbolEffect(.bounce, options: .repeating)
                } else {
                    // Fallback on earlier versions
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

    private var dealerBadgeGradient: LinearGradient {
        switch colorScheme {
        case .dark:
            return LinearGradient(
                colors: [Color(red: 0.2, green: 0.45, blue: 0.28), Color(red: 0.12, green: 0.32, blue: 0.2)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        default:
            return LinearGradient(
                colors: [Color(red: 0.15, green: 0.55, blue: 0.25), Color(red: 0.08, green: 0.42, blue: 0.18)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var backgroundGradient: LinearGradient {
        switch colorScheme {
        case .light:
            return LinearGradient(
                colors: [
                    Color(red: 0.0, green: 0.55, blue: 0.25),
                    Color(red: 0.5, green: 0.95, blue: 0.55)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        case .dark:
            return LinearGradient(
                colors: [
                    Color(red: 0.03, green: 0.16, blue: 0.10),
                    Color(red: 0.02, green: 0.28, blue: 0.18)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        @unknown default:
            return LinearGradient(
                colors: [Color.green, Color.green.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private var header: some View {
        VStack(spacing: 4) {
            ZStack {
                HStack {
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

                    Spacer()
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
                }

                Text("Hearts Scoreboard")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color.white)
            }

            HStack {
                Text(headerSubtitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .allowsTightening(true)

                Spacer()

                Text(String(format: String(localized: "Game to: %d"), model.settings.endingScore))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.white)
            }
            .padding(.horizontal, 70)
        }
        .padding(.vertical, 12)
    }

    private var headerSubtitle: String {
        if model.isGameOver {
            return model.statusText
        }

        switch model.game.hands.count % 3 {
        case 0:
            return String(localized: "Pass: Left \u{2190}")
        case 1:
            return String(localized: "Pass: Right \u{2192}")
        default:
            return String(localized: "Pass: Hold \u{270B}")
        }
    }

    private var leadingPlayerIDs: Set<UUID> {
        let totals = model.game.totals()
        guard let minTotal = totals.map(\.total).min() else { return [] }
        let leaders = totals.filter { $0.total == minTotal }.map { $0.player.id }
        return Set(leaders)
    }

    private var scoreboardCardBackground: Color {
        switch colorScheme {
        case .dark:
            return Color(red: 0.10, green: 0.18, blue: 0.14)
        default:
            return Color(red: 0.86, green: 1.0, blue: 0.91)
        }
    }

    private var scoreboard: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(.ultraThinMaterial)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(scoreboardCardBackground.opacity(colorScheme == .dark ? 0.9 : 0.85))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(colorScheme == .dark ? 0.20 : 0.35), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.45 : 0.20), radius: 18, x: 0, y: 10)
            .overlay(alignment: .top) {
                scoreboardContent
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .padding(.top, 8)
    }

    private var scoreboardContent: some View {
        VStack(spacing: 12) {
            VStack(spacing: 8) {
                HStack(spacing: 0) {
                    ForEach(Array(model.game.players.enumerated()), id: \.element.id) { index, player in
                        VStack(spacing: 6) {
                            ZStack {
                                if index == dealerIndex {
                                    dealerBadge
                                }
                            }
                            .frame(height: 25)
                            Text(player.name)
                                .font(.headline.weight(.semibold))
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .padding(.vertical, 4)
                                .padding(.horizontal, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(
                                            Color.white.opacity(colorScheme == .dark ? 0.10 : 0.26)
                                        )
                                )
                                .frame(maxWidth: .infinity)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(maxWidth: .infinity)

                HStack {
                    ForEach(model.game.players) { player in
                        PlayerTotalBadge(
                            total: model.game.totalPoints(for: player.id),
                            isLeader: leadingPlayerIDs.contains(player.id),
                            colorScheme: colorScheme
                        )
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.black.opacity(colorScheme == .dark ? 0.14 : 0.06))
            )

            ScrollViewReader { proxy in
                scoresScroll(proxy: proxy)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.vertical, 6)
        .padding(.horizontal, 6)
    }

    private func scoresScroll(proxy: ScrollViewProxy) -> some View {
        ScrollView {
            HStack(alignment: .top, spacing: 0) {
                ForEach(model.game.players) { player in
                    VStack(spacing: 8) {
                        ForEach(Array(model.game.hands.enumerated()), id: \.element.id) { index, hand in
                            let score = hand.pointsByPlayerID[player.id] ?? 0
                            let isEvenRow = index.isMultiple(of: 2)
                            let isMoon = model.game.isMoonHand(hand, for: player.id)
                            Group {
                                if isMoon {
                                    Image(systemName: "moon.fill")
                                } else {
                                    Text("\(score)")
                                }
                            }
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(Color.primary)
                            .frame(width: 56, height: 26)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(
                                        (isEvenRow
                                         ? Color.white.opacity(colorScheme == .dark ? 0.15 : 0.35)
                                         : Color.white.opacity(colorScheme == .dark ? 0.3 : 0.7)
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
        .scrollIndicators(.visible)
        .onChange(of: model.game.hands.count) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                if let lastHand = model.game.hands.last {
                    proxy.scrollTo(lastHand.id, anchor: .bottom)
                }
            }
        }
    }

    private var bottomBar: some View {
        HStack {
            Button {
                showNewGameAlert = true
            } label: {
                Label("New Game", systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(.bordered)
            .tint(.blue)
            .frame(maxWidth: .infinity, alignment: .leading)
            .disabled(model.game.hands.isEmpty)

            Spacer()

            Button {
                showingRoundInput = true
            } label: {
                Label("Next Round", systemImage: "arrow.right.circle.fill")
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .disabled(model.isGameOver)
        }
        .font(.callout)
        .padding(.vertical, 12)
    }
}

#Preview {
    GameView()
}
