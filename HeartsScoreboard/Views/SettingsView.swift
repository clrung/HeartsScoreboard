import SwiftUI
import Observation

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var model: GameViewModel
    @State private var showingAbout = false

    /// Scheme the in-app preference forces; nil follows the system.
    private var preferredScheme: ColorScheme? {
        switch model.settings.appearance {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                playersSection
                rulesSection
                appearanceSection
                aboutSection
            }
            .navigationTitle("Settings")
            // Reorder/delete handles for the player rows. Rows that need normal taps are Buttons
            // (a NavigationLink row would not respond in edit mode), hence About below.
            .environment(\.editMode, .constant(.active))
            .navigationDestination(isPresented: $showingAbout) { AboutView() }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("settings.done")
                }
            }
        }
        // The app root applies the stored preference to the window, but a presented sheet doesn't
        // reliably pick up a mid-presentation change; applying it here updates Settings immediately
        // (and nil falls back to the system scheme).
        .preferredColorScheme(preferredScheme)
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
                Text(String(format: String(localized: "Adds %d points per tap"), model.settings.quickIncrementPoints))
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
            }

            Toggle("10♦ worth −10", isOn: $model.settings.tenOfDiamondsMinus10)
        } header: {
            Text("Game Rules")
        } footer: {
            Text("Omnibus Hearts variant: whoever takes the 10♦ scores −10 for that hand. It is separate from shooting the moon.")
        }
    }

    // MARK: Appearance / About

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

    private var aboutSection: some View {
        Section {
            Button {
                showingAbout = true
            } label: {
                HStack {
                    Label("About", systemImage: "info.circle")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .foregroundStyle(.primary)
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
