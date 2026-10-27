import SwiftUI
import Observation

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var model: GameViewModel
    @State private var showingAbout = false

    var body: some View {
        NavigationStack {
            Form {
                playersSection
                rulesSection
                moonSection
                appearanceSection
            }
            .navigationTitle("Settings")
            // Reorder/delete handles for the player rows. Rows that need normal taps are Buttons
            // (a NavigationLink row would not respond in edit mode).
            .environment(\.editMode, .constant(.active))
            .navigationDestination(isPresented: $showingAbout) { AboutView() }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingAbout = true
                    } label: {
                        Image(systemName: "info.circle.fill")
                    }
                    .accessibilityLabel("About")
                    .accessibilityIdentifier("settings.about")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("settings.done")
                }
            }
        }
    }

    // MARK: Players

    private var playersSection: some View {
        Section {
            Group {
                if model.game.players.count > 3 {
                    ForEach($model.game.players) { $player in
                        TextField("Player", text: $player.name)
                    }
                    .onMove(perform: model.movePlayers)
                    .onDelete(perform: model.deletePlayers)
                } else {
                    ForEach($model.game.players) { $player in
                        TextField("Player", text: $player.name)
                    }
                    .onMove(perform: model.movePlayers)
                }
            }

            if model.game.players.count < 6 {
                Button {
                    model.addPlayer()
                } label: {
                    Label("Add Player", systemImage: "plus.circle.fill")
                }
            }

            suggestionsRow

            Picker("Dealer", selection: dealerBinding) {
                ForEach(Array(model.game.players.enumerated()), id: \.element.id) { index, player in
                    Text(player.name).tag(index)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: model.game.players.count) { _, newCount in
                if model.firstDealerIndex >= newCount {
                    model.firstDealerIndex = max(0, newCount - 1)
                }
            }
        } header: {
            Text("Players")
        } footer: {
            Text("Hearts supports 3–6 players.")
        }
    }

    @ViewBuilder
    private var suggestionsRow: some View {
        let names = model.suggestedPlayerNames()
        let canSeat = model.game.players.count < 6
            || model.game.players.contains { PlayerNameSuggestions.isPlaceholder($0.name) }
        if !names.isEmpty && canSeat {
            VStack(alignment: .leading, spacing: 8) {
                Text("Recent players")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(names, id: \.self) { name in
                            Button {
                                model.useSuggestedPlayerName(name)
                            } label: {
                                Text(name)
                                    .lineLimit(1)
                                    .padding(.horizontal, 12)
                                    .frame(minHeight: 44)
                                    .background(Capsule().fill(Theme.accent.opacity(0.15)))
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(Theme.accent)
                            .accessibilityLabel(Text(String(format: String(localized: "Add %@"), name)))
                        }
                    }
                }
            }
            .accessibilityIdentifier("settings.recentPlayers")
        }
    }

    // MARK: Game rules

    private var rulesSection: some View {
        Section {
            VStack(alignment: .leading) {
                Text(String(format: String(localized: "Ending Score: %d"), model.settings.endingScore))
                Slider(
                    value: Binding(
                        get: { Double(model.settings.endingScore) },
                        set: { model.settings.endingScore = Int($0) }
                    ),
                    in: 50...150,
                    step: 5
                )
                .accessibilityLabel("Ending Score")
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(DirectionalUI.quickAddTitle(points: model.settings.quickIncrementPoints))
                Slider(
                    value: Binding(
                        get: { Double(model.settings.quickIncrementPoints) },
                        set: { newValue in
                            model.settings.quickIncrementPoints = GameSettings.clampQuickIncrement(Int(newValue.rounded()))
                        }
                    ),
                    in: 2...9,
                    step: 1
                )
                .accessibilityLabel("Quick add")
                Text(String(format: String(localized: "The +%d button in score entry adds this many points per tap."), model.settings.quickIncrementPoints))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Toggle("10♦ worth −10", isOn: $model.settings.tenOfDiamondsMinus10)
        } header: {
            Text("Game Rules")
        } footer: {
            Text("Omnibus Hearts variant: whoever takes the 10♦ scores −10 for that hand. It is separate from shooting the moon.")
        }
    }

    /// Also reachable mid-game from the round-entry header; same binding, synced via iCloud.
    private var moonSection: some View {
        Section {
            Picker("Shoot the moon", selection: $model.settings.shootMoonPreference) {
                ForEach(ShootMoonPreference.allCases) { pref in
                    Text(pref.label).tag(pref)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("settings.shootMoonPreference")
        } header: {
            Text("Shoot the Moon Preference")
        } footer: {
            switch model.settings.shootMoonPreference {
            case .add26: Text("Adds 26 points to every other players' score.")
            case .subtract26: Text("Subtracts 26 points from the selected player's score.")
            }
        }
    }

    // MARK: Appearance

    private var appearanceSection: some View {
        Section("Appearance") {
            Picker("Appearance", selection: appearanceBinding) {
                ForEach(AppearancePreference.allCases) { pref in
                    Text(pref.label).tag(pref)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    /// Binding so the Picker shows/sets the current dealer (for next round), not just “first” dealer.
    private var dealerBinding: Binding<Int> {
        let n = model.game.players.count
        return Binding(
            get: { model.currentDealerIndex },
            set: { newIndex in
                guard n > 0 else { return }
                model.firstDealerIndex = (newIndex - model.game.hands.count % n + n) % n
            }
        )
    }

    /// Appearance is stored locally (UserDefaults via `setAppearance`) and deliberately not synced via iCloud.
    private var appearanceBinding: Binding<AppearancePreference> {
        Binding(
            get: { model.settings.appearance },
            set: { newValue in
                model.setAppearance(newValue)
            }
        )
    }
}

#Preview {
    SettingsView(model: GameViewModel())
}
