import SwiftUI
import Observation

struct RoundInputView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Bindable var model: GameViewModel

    @State private var points: [UUID: Int] = [:]
    @State private var queenOwnerID: UUID? = nil

    private var leadingPlayerIDs: Set<UUID> {
        let totals = model.game.totals()
        guard let minTotal = totals.map(\.total).min() else { return [] }
        return Set(totals.filter { $0.total == minTotal }.map { $0.player.id })
    }

    private var isAllScoresZero: Bool {
        model.game.players.allSatisfy { (points[$0.id] ?? 0) == 0 }
    }

    var body: some View {
        NavigationStack {
            VStack {
                Form {
                    Section {
                        ForEach(model.game.players) { player in
                            HStack(alignment: .center, spacing: 0) {
                                PlayerNameWithTotalView(
                                    name: player.name,
                                    total: model.game.totalPoints(for: player.id),
                                    isLeader: leadingPlayerIDs.contains(player.id),
                                    colorScheme: colorScheme
                                )
                                .frame(width: 130, alignment: .leading)
                                .frame(maxHeight: .infinity, alignment: .center)

                                HStack(spacing: -4) {
                                    Button {
                                        adjustPoints(for: player.id, delta: -1)
                                    } label: {
                                        Image(systemName: "minus.circle.fill")
                                            .font(.title3.weight(.semibold))
                                    }
                                    .buttonStyle(.borderless)
                                    .frame(width: 32, alignment: .center)
                                    .foregroundStyle(isRoundValid || (points[player.id] ?? 0) == 0 ? Color.secondary.opacity(0.5) : Color.red)
                                    .disabled(isRoundValid || (points[player.id] ?? 0) == 0)

                                    Text("\(points[player.id] ?? 0)")
                                        .font(.title3.weight(.semibold))
                                        .monospacedDigit()
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.6)
                                        .frame(width: 32, alignment: .center)

                                    Button {
                                        adjustPoints(for: player.id, delta: 1)
                                    } label: {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.title3.weight(.semibold))
                                    }
                                    .buttonStyle(.borderless)
                                    .frame(width: 32, alignment: .center)
                                    .foregroundStyle(isRoundValid ? Color.secondary.opacity(0.5) : Color.blue)
                                    .disabled(isRoundValid)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(maxHeight: .infinity, alignment: .center)

                                HStack(spacing: 0) {
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
                                        .disabled(isRoundValid || remainingPoints(for: player.id) < 5)

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
                                        Button {
                                            addRemainingPoints(for: player.id)
                                        } label: {
                                            Text(isShootTheMoonRound ? "+0" : "+\(remaining)")
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

                Button {
                    submit()
                } label: {
                    Text("Submit")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .contentShape(Rectangle())
                        .background {
                            Capsule(style: .continuous)
                                .fill(.ultraThinMaterial)
                                .overlay {
                                    Capsule(style: .continuous)
                                        .fill(Color.blue.opacity(1.0))
                                }
                                .shadow(color: .black.opacity(colorScheme == .dark ? 0.5 : 0.1), radius: 8, y: 4)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Submit round scores"))
                .opacity(isRoundValid ? 1 : 0.5)
                .disabled(!isRoundValid)
                .padding(.horizontal)
                .padding(.vertical)
            }
            .navigationTitle(String(format: String(localized: "Round %d"), model.game.hands.count + 1))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Label("Back", systemImage: "chevron.left")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        reset()
                    } label: {
                        Label("Reset", systemImage: "arrow.counterclockwise")
                    }
                    .disabled(isAllScoresZero)
                }
            }
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

    /// Shoot the moon: Add 26 = shooter gets 0, everyone else gets 26. Subtract 26 = shooter gets -26, everyone else gets 0.
    private func applyShootMoonValue(for shooterID: UUID) {
        switch model.settings.shootMoonPreference {
        case .add26:
            for p in model.game.players {
                points[p.id] = p.id == shooterID ? 0 : 26
            }
        case .subtract26:
            for p in model.game.players {
                points[p.id] = p.id == shooterID ? -26 : 0
            }
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

    /// True when the round is valid and is a shoot-the-moon outcome (not a normal 26 split). Subtract buttons should be disabled in this case.
    private var isShootTheMoonRound: Bool {
        let n = model.game.players.count
        guard n > 0, isRoundValid else { return false }
        let sum = model.game.players.reduce(0) { $0 + (points[$1.id] ?? 0) }
        return sum == -26 || sum == (n - 1) * 26
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

