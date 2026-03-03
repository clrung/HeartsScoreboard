import SwiftUI
import Observation

struct HistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var model: GameViewModel

    private var sortedHistory: [CompletedGame] {
        model.history.sorted { $0.finishedAt > $1.finishedAt }
    }

    var body: some View {
        NavigationStack {
            List {
                if sortedHistory.isEmpty {
                    Text("No completed games yet.")
                        .foregroundStyle(.secondary)
                } else {
                    Section {
                        ForEach(sortedHistory) { game in
                            NavigationLink {
                                HistoryDetailView(completedGame: game)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(game.finishedAt, format: .dateTime.month().day().year())
                                            .font(.subheadline)
                                        Text(game.finishedAt, format: .dateTime.hour().minute())
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    Text(game.winnerDescription)
                                        .font(.subheadline.weight(.semibold))
                                        .multilineTextAlignment(.trailing)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .onDelete { offsets in
                            // Map visible rows back to the model's history indices.
                            let toDelete = offsets.map { sortedHistory[$0].id }
                            let modelOffsets = IndexSet(
                                model.history.enumerated()
                                    .compactMap { index, item in
                                        toDelete.contains(item.id) ? index : nil
                                    }
                            )
                            model.deleteHistory(at: modelOffsets)
                        }
                    } header: {
                        HStack {
                            Text("Time")
                            Spacer()
                            Text("Winner")
                        }
                        .font(.caption.weight(.semibold))
                        .textCase(nil)
                    }
                }
            }
            .navigationTitle("Game History")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

