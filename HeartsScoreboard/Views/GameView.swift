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
            backgroundColor
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

    private var header: some View {
        ZStack {
            HStack {
                Spacer()
                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.title2)
                        .foregroundStyle(.primary)
                }
            }

            Text("Hearts Scoreboard")
                .font(.title2.weight(.semibold))
        }
        .padding(.vertical, 12)
    }

    private var scoreboardCardBackground: Color {
        switch colorScheme {
        case .dark:
            return Color(red: 0.14, green: 0.22, blue: 0.18)
        default:
            return Color(red: 0.8, green: 1, blue: 0.7)
        }
    }

    private var scoreboard: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(scoreboardCardBackground)
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.05), radius: 8, x: 0, y: 4)
            .overlay(alignment: .top) {
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
                                    .font(.headline)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                    .frame(maxWidth: .infinity)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(maxWidth: .infinity)

                    ScrollView {
                        HStack(alignment: .top, spacing: 0) {
                            ForEach(model.game.players) { player in
                                VStack(spacing: 8) {
                                    ForEach(model.game.hands) { hand in
                                        let score = hand.pointsByPlayerID[player.id] ?? 0
                                        Text("\(score)")
                                            .font(.body.weight(.medium))
                                            .frame(width: 56, height: 28)
                                            .background(
                                                Capsule()
                                                    .fill(Color(.systemGreen).opacity(0.15))
                                            )
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .top)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 8)
                    }
                    .frame(maxHeight: .infinity)
                    .scrollIndicators(.visible)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.vertical, 16)
                .padding(.horizontal, 4)
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .padding(.top, 8)
    }

    private var bottomBar: some View {
        VStack(spacing: 8) {
            HStack {
                ForEach(model.game.players) { player in
                    Text("\(model.game.totalPoints(for: player.id))")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
            }

            HStack {
                Button("New Game") {
                    showNewGameAlert = true
                }
                .buttonStyle(.bordered)
                .tint(.blue)
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(model.statusText)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .frame(maxWidth: .infinity)

                Button("Next Round") {
                    showingRoundInput = true
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .disabled(model.isGameOver)
            }
            .font(.callout)
        }
        .padding(.vertical, 12)
    }
}

#Preview {
    GameView()
}
