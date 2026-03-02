import SwiftUI

struct GameView: View {
    @State private var model = GameViewModel()
    @State private var showingRoundInput = false
    @State private var showingSettings = false

    var body: some View {
        ZStack {
            backgroundColor
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                scoreboard
                Spacer()
                bottomBar
            }
            .padding(.horizontal)
        }
        .sheet(isPresented: $showingRoundInput) {
            RoundInputView(model: model)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(model: model)
        }
    }

    private var backgroundColor: Color {
        switch model.settings.theme {
        case .light: return Color(.systemGreen).opacity(0.3)
        case .green: return Color.green
        case .dark: return Color(.darkGray).opacity(0.8)
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

    private var scoreboard: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color(.systemBackground))
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
            .overlay {
                VStack(spacing: 12) {
                    HStack(alignment: .top, spacing: 0) {
                        ForEach(model.game.players) { player in
                            VStack(spacing: 8) {
                                Text(player.name)
                                    .font(.headline)

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
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 4)
            }
            .frame(alignment: .top)
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
                    model.newGame()
                }
                .buttonStyle(.bordered)
                .tint(.blue)
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(model.statusText)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)

                Button("Next Round") {
                    showingRoundInput = true
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .font(.callout)
        }
        .padding(.vertical, 12)
    }
}

#Preview {
    GameView()
}
