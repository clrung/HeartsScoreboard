import SwiftUI
import Observation

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var model: GameViewModel
    @State private var showingAbout = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Players") {
                    ForEach($model.game.players) { $player in
                        TextField("Player", text: $player.name)
                    }
                    .onMove(perform: model.movePlayers)
                    .onDelete(perform: model.deletePlayers)

                    if model.game.players.count < 6 {
                        Button {
                            model.addPlayer()
                        } label: {
                            Label("Add Player", systemImage: "plus.circle.fill")
                        }
                    }

                    if model.game.players.count <= 3 {
                        Text("Hearts supports 3–6 players.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

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

                Section("Shoot the Moon Preference") {
                    Picker("Shoot the moon", selection: $model.settings.shootMoonPreference) {
                        ForEach(ShootMoonPreference.allCases) { pref in
                            Text(pref.label).tag(pref)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section("Ending Score") {
                    VStack(alignment: .leading) {
                        Text("Ending Score: \(model.settings.endingScore)")
                        Slider(
                            value: Binding(
                                get: { Double(model.settings.endingScore) },
                                set: { model.settings.endingScore = Int($0) }
                            ),
                            in: 50...150,
                            step: 5
                        )
                    }
                }
            }
            .navigationTitle("Settings")
            .environment(\.editMode, .constant(.active))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingAbout = true
                    } label: {
                        Image(systemName: "info.circle.fill")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingAbout) {
                AboutView()
            }
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

}

#Preview {
    SettingsView(model: GameViewModel())
}

