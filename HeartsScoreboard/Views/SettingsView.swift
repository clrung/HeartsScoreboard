import SwiftUI
import Observation

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var model: GameViewModel

    var body: some View {
        NavigationStack {
            Form {
                Section("Players") {
                    ForEach(model.game.players.indices, id: \.self) { index in
                        TextField("Player \(index + 1)", text: $model.game.players[index].name)
                    }
                }

                Section("Theme") {
                    Picker("Theme", selection: $model.settings.theme) {
                        Text("Light").tag(BoardTheme.light)
                        Text("Green").tag(BoardTheme.green)
                        Text("Dark").tag(BoardTheme.dark)
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
                            in: 50...200,
                            step: 5
                        )
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
            }
            .navigationTitle("Hearts Scoreboard")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    SettingsView(model: GameViewModel())
}

