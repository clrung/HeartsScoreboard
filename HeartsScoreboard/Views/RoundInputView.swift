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
                                .frame(width: 44)

                                Button("+26") {
                                    setPoints(for: player.id, to: 26)
                                }
                                .buttonStyle(.borderedProminent)
                                .frame(width: 52)
                            }
                        }
                    }
                }

                HStack {
                    Button("Submit") {
                        submit()
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Reset") {
                        reset()
                    }

                    Button("Back") {
                        dismiss()
                    }
                }
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
        let newValue = max(0, min(26, current + delta))
        points[playerID] = newValue
    }

    private func setPoints(for playerID: UUID, to value: Int) {
        let newValue = max(0, min(26, value))
        points[playerID] = newValue
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

