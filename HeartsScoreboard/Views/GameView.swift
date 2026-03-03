import SwiftUI

struct GameView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var model = GameViewModel(initialState: CloudSyncManager.shared.load())
    @State private var showingRoundInput = false
    @State private var showingSettings = false
    @State private var showUndoAlert = false
    @State private var showNewGameAlert = false

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
        .onAppear {
            CloudSyncManager.shared.onSyncFromCloud = { [model] state in
                model.applySyncedState(state)
            }
        }
        .onChange(of: showingSettings) { _, isShowing in
            if !isShowing { model.persistToCloud() }
        }
    }

    private var dealerIndex: Int { model.currentDealerIndex }

    private var dealerBadge: some View {
        Text("D")
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: 26, height: 26)
            .background {
                Circle()
                    .fill(dealerBadgeGradient)
            }
            .overlay {
                Circle()
                    .strokeBorder(Color.white.opacity(colorScheme == .dark ? 0.35 : 0.5), lineWidth: 1)
            }
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.4 : 0.15), radius: 2, x: 0, y: 1)
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

    private var backgroundColor: Color {
        switch colorScheme {
        case .light:
            return Color.green
        case .dark:
            return Color(red: 0.08, green: 0.18, blue: 0.12)
        @unknown default:
            return Color.green
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
            }

            HStack {
                Text(headerSubtitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Spacer()

                Text("Game to: \(model.settings.endingScore)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
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
            return "Passing: Left \u{2190}"
        case 1:
            return "Passing: Right \u{2192}"
        default:
            return "Passing: Hold \u{270B}"
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
            HStack(spacing: 0) {
                ForEach(Array(model.game.players.enumerated()), id: \.element.id) { index, player in
                    VStack(spacing: 6) {
                        ZStack {
                            if index == dealerIndex {
                                dealerBadge
                            }
                        }
                        .frame(height: 30)
                        Text(player.name)
                            .font(.headline.weight(.bold))
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .padding(.horizontal, 8)
                            .frame(maxWidth: .infinity)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(maxWidth: .infinity)

            HStack {
                ForEach(model.game.players) { player in
                    let isLeader = leadingPlayerIDs.contains(player.id)
                    Text("\(model.game.totalPoints(for: player.id))")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(isLeader ? Color.primary : Color.primary.opacity(0.9))
                        .padding(.vertical, 4)
                        .frame(maxWidth: .infinity)
                        .background(
                            Capsule(style: .continuous)
                                .fill(
                                    isLeader
                                    ? Color.yellow.opacity(colorScheme == .dark ? 0.35 : 0.45)
                                    : Color.white.opacity(colorScheme == .dark ? 0.08 : 0.18)
                                )
                        )
                }
            }

            ScrollViewReader { proxy in
                scoresScroll(proxy: proxy)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.vertical, 16)
        .padding(.horizontal, 4)
    }

    private func scoresScroll(proxy: ScrollViewProxy) -> some View {
        ScrollView {
            HStack(alignment: .top, spacing: 0) {
                ForEach(model.game.players) { player in
                    VStack(spacing: 8) {
                        ForEach(Array(model.game.hands.enumerated()), id: \.element.id) { index, hand in
                            let score = hand.pointsByPlayerID[player.id] ?? 0
                            let isEvenRow = index.isMultiple(of: 2)
                            Text("\(score)")
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(Color.primary)
                                .frame(width: 56, height: 26)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(
                                            (isEvenRow
                                             ? Color.white.opacity(colorScheme == .dark ? 0.18 : 0.30)
                                             : Color.white.opacity(colorScheme == .dark ? 0.26 : 0.42)
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
