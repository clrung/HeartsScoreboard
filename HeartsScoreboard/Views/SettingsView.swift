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
                    ForEach(model.game.players.indices, id: \.self) { index in
                        TextField("Player", text: $model.game.players[index].name)
                    }
                    .onMove(perform: movePlayers)
                }

                Section("Dealer") {
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
                }

                Section("Shoot the moon preference") {
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
            .navigationTitle("Hearts Scoreboard")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
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

    private func movePlayers(from source: IndexSet, to destination: Int) {
        model.game.players.move(fromOffsets: source, toOffset: destination)
    }
}

#Preview {
    SettingsView(model: GameViewModel())
}

