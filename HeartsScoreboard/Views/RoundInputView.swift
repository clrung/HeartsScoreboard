import SwiftUI
import Observation

struct RoundInputView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var model: GameViewModel

    @State private var points: [UUID: Int] = [:]

    var body: some View {
        NavigationStack {
            VStack {
                Form {
                    ForEach(model.game.players) { player in
                        HStack {
                            Text(player.name)
                                .frame(width: 110, alignment: .leading)
                            Spacer()

                            HStack(spacing: 8) {
                                Button("-") {
                                    adjustPoints(for: player.id, delta: -1)
                                }
                                .buttonStyle(.borderless)
                                .frame(width: 24)

                                Text("\(points[player.id] ?? 0)")
                                    .frame(width: 32)
                                    .font(.headline)

                                Button("+") {
                                    adjustPoints(for: player.id, delta: 1)
                                }
                                .buttonStyle(.borderless)
                                .frame(width: 24)

                                Button("+5") {
                                    adjustPoints(for: player.id, delta: 5)
                                }
                                .buttonStyle(.borderedProminent)
                                .lineLimit(1)
                                .minimumScaleFactor(0.9)
                                .frame(width: 44)

                                Button(shootMoonButtonTitle) {
                                    applyShootMoonValue(for: player.id)
                                }
                                .buttonStyle(.borderedProminent)
                                .lineLimit(1)
                                .minimumScaleFactor(0.9)
                                .frame(width: 60)
                            }
                        }
                    }
                }

                HStack(spacing: 16) {
                    Button("Back") {
                        dismiss()
                    }

                    Spacer()

                    Button("Submit") {
                        submit()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal)
                .padding(.vertical)
            }
            .navigationTitle("Hearts Scoreboard")
        }
        .onAppear {
            if points.isEmpty {
                reset()
            }
        }
    }

    private func adjustPoints(for playerID: UUID, delta: Int) {
        let current = points[playerID] ?? 0
        let newValue = max(minimumRoundScore, min(26, current + delta))
        points[playerID] = newValue
    }

    private func setPoints(for playerID: UUID, to value: Int) {
        let newValue = max(minimumRoundScore, min(26, value))
        points[playerID] = newValue
    }

    private func applyShootMoonValue(for playerID: UUID) {
        let value = model.settings.shootMoonPreference == .subtract26 ? -26 : 26
        setPoints(for: playerID, to: value)
    }

    private var shootMoonButtonTitle: String {
        model.settings.shootMoonPreference == .subtract26 ? "-26" : "+26"
    }

    private var minimumRoundScore: Int {
        model.settings.shootMoonPreference == .subtract26 ? -26 : 0
    }

    private func reset() {
        var dict: [UUID: Int] = [:]
        for p in model.game.players {
            dict[p.id] = 0
        }
        points = dict
    }

    private func submit() {
        model.addHand(pointsByPlayerID: points)
        dismiss()
    }
}

#Preview {
    RoundInputView(model: GameViewModel())
}

