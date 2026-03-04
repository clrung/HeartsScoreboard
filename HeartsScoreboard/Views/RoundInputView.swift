import SwiftUI
import Observation

struct RoundInputView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Bindable var model: GameViewModel

    @State private var points: [UUID: Int] = [:]
    @State private var queenOwnerID: UUID? = nil

    private var showNavigationTitle: Bool { verticalSizeClass != .compact }

    var body: some View {
        NavigationStack {
            VStack {
                Form {
                    Section {
                        ForEach(model.game.players) { player in
                            HStack(alignment: .center, spacing: 12) {
                                Text(player.name)
                                    .font(.headline.weight(.semibold))
                                    .frame(width: 110, alignment: .leading)
                                    .frame(maxHeight: .infinity, alignment: .center)

                                HStack(spacing: 8) {
                                    Button("-") {
                                        adjustPoints(for: player.id, delta: -1)
                                    }
                                    .buttonStyle(.borderless)
                                    .font(.headline)
                                    .disabled(isRoundValid)

                                    Text("\(points[player.id] ?? 0)")
                                        .font(.title3.weight(.semibold))
                                        .monospacedDigit()
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.6)
                                        .frame(width: 44)

                                    Button("+") {
                                        adjustPoints(for: player.id, delta: 1)
                                    }
                                    .buttonStyle(.borderless)
                                    .font(.headline)
                                    .disabled(isRoundValid)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(maxHeight: .infinity, alignment: .center)

                                HStack(spacing: 12) {
                                    VStack(spacing: 4) {
                                        Button("+5") {
                                            adjustPoints(for: player.id, delta: 5)
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .font(.subheadline.weight(.semibold))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.6)
                                        .allowsTightening(true)
                                        .frame(width: 52, height: 32)
                                        .disabled(isRoundValid)

                                        Button("Q♠") {
                                            addQueenOfSpades(for: player.id)
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .font(.subheadline.weight(.semibold))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.6)
                                        .allowsTightening(true)
                                        .frame(width: 52, height: 32)
                                        .disabled(isRoundValid || queenOwnerID != nil)
                                    }

                                    VStack(spacing: 4) {
                                        let remaining = remainingPoints(for: player.id)
                                        Button("+\(remaining)") {
                                            addRemainingPoints(for: player.id)
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .font(.subheadline.weight(.semibold))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.6)
                                        .allowsTightening(true)
                                        .frame(width: 52, height: 32)
                                        .disabled(remaining == 0 || isRoundValid)

                                        Button {
                                            applyShootMoonValue(for: player.id)
                                        } label: {
                                            Image(systemName: "moon.fill")
                                                .font(.subheadline.weight(.semibold))
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .frame(width: 52, height: 32)
                                        .disabled(isRoundValid)
                                    }
                                }
                            }
                        }
                    }

                    Section("Shoot the Moon Preference") {
                        Picker("Shoot the moon", selection: $model.settings.shootMoonPreference) {
                            ForEach(ShootMoonPreference.allCases) { pref in
                                Text(pref.label).tag(pref)
                            }
                        }
                        .pickerStyle(.segmented)

                        VStack(alignment: .leading, spacing: 4) {
                            if model.settings.shootMoonPreference == .add26 {
                                Text("Adds 26 points to every other players' score.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }

                            if model.settings.shootMoonPreference == .subtract26 {
                                Text("Subtracts 26 points from the selected player's score.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.top, 4)
                    }
                }

                HStack(spacing: 16) {
                    Button("Back") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    .tint(.blue)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Button("Reset") {
                        reset()
                    }
                    .buttonStyle(.bordered)
                    .tint(.blue)
                    .frame(maxWidth: .infinity)

                    Button("Submit") {
                        submit()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .disabled(!isRoundValid)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(.horizontal)
                .padding(.vertical)
            }
            .navigationTitle(showNavigationTitle ? "Round \(model.game.hands.count + 1)" : "")
            .navigationBarTitleDisplayMode(.inline)
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

    private func addQueenOfSpades(for playerID: UUID) {
        adjustPoints(for: playerID, delta: 13)
        if queenOwnerID == nil {
            queenOwnerID = playerID
        }
    }

    private func remainingPoints(for playerID: UUID) -> Int {
        let total = model.game.players.reduce(0) { $0 + (points[$1.id] ?? 0) }
        let remaining = 26 - total
        return max(0, remaining)
    }

    private func addRemainingPoints(for playerID: UUID) {
        let delta = remainingPoints(for: playerID)
        guard delta > 0 else { return }
        adjustPoints(for: playerID, delta: delta)
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

    /// Valid Hearts round: total is 26 (split among ≥2 players), -26, or (players - 1) * 26 (shoot the moon). One player having 26 and the rest 0 is invalid.
    private var isRoundValid: Bool {
        let n = model.game.players.count
        guard n > 0 else { return false }
        let sum = model.game.players.reduce(0) { $0 + (points[$1.id] ?? 0) }
        let shootMoonTotal = (n - 1) * 26
        if sum == 26 {
            let hasSomeoneWith26 = model.game.players.contains { (points[$0.id] ?? 0) == 26 }
            if hasSomeoneWith26 { return false }
            return true
        }
        return sum == -26 || sum == shootMoonTotal
    }

    private func reset() {
        var dict: [UUID: Int] = [:]
        for p in model.game.players {
            dict[p.id] = 0
        }
        points = dict
        queenOwnerID = nil
    }

    private func submit() {
        model.addHand(pointsByPlayerID: points)
        dismiss()
    }
}

#Preview {
    RoundInputView(model: GameViewModel())
}

