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

                                Button {
                                    applyShootMoonValue(for: player.id)
                                } label: {
                                    Image(systemName: "moon.fill")
                                }
                                .buttonStyle(.borderedProminent)
                                .frame(width: 44, height: 36)
                            }
                        }
                    }
                }

                HStack(spacing: 16) {
                    Button("Back") {
                        dismiss()
                    }

                    Spacer()

                    Button("Reset") {
                        reset()
                    }

                    Spacer()

                    Button("Submit") {
                        submit()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!isRoundValid)
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

    /// Shoot the moon: Add 26 = shooter gets 0, everyone else gets 26. Subtract 26 = tapped player gets -26, others unchanged.
    private func applyShootMoonValue(for shooterID: UUID) {
        switch model.settings.shootMoonPreference {
        case .add26:
            for p in model.game.players {
                points[p.id] = p.id == shooterID ? 0 : 26
            }
        case .subtract26:
            let current = points[shooterID] ?? 0
            points[shooterID] = max(-26, current - 26)
        }
    }

    private var minimumRoundScore: Int {
        model.settings.shootMoonPreference == .subtract26 ? -26 : 0
    }

    /// Valid Hearts round: total is 26, -26, or (players - 1) * 26 (shoot the moon).
    private var isRoundValid: Bool {
        let n = model.game.players.count
        guard n > 0 else { return false }
        let sum = model.game.players.reduce(0) { $0 + (points[$1.id] ?? 0) }
        let shootMoonTotal = (n - 1) * 26
        return sum == 26 || sum == -26 || sum == shootMoonTotal
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

