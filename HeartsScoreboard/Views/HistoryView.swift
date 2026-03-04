import SwiftUI
import Observation

struct HistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var model: GameViewModel
    @AppStorage("HeartsScoreboardHistoryDeleteHintShown") private var hasSeenDeleteHint = false
    @State private var showDeletePeek = false

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
                        ForEach(Array(sortedHistory.enumerated()), id: \.element.id) { index, game in
                            NavigationLink {
                                HistoryDetailView(completedGame: game)
                            } label: {
                                let isPeekRow = index == 0 && showDeletePeek

                                ZStack(alignment: .trailing) {
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
                                    .offset(x: isPeekRow ? -72 : 0)

                                    if index == 0 {
                                        Image(systemName: "trash.fill")
                                            .font(.title3)
                                            .foregroundStyle(.white)
                                            .padding(.vertical, 8)
                                            .padding(.horizontal, 12)
                                            .background(Color.red)
                                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                            .opacity(isPeekRow ? 1 : 0)
                                    }
                                }
                                .animation(.easeInOut(duration: 0.35), value: showDeletePeek)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    delete(game: game)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
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
            .onAppear {
                if !hasSeenDeleteHint, !sortedHistory.isEmpty {
                    hasSeenDeleteHint = true
                    showDeletePeek = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        withAnimation {
                            showDeletePeek = false
                        }
                    }
                }
            }
        }
    }
}

private extension HistoryView {
    func delete(game: CompletedGame) {
        guard let idx = model.history.firstIndex(where: { $0.id == game.id }) else { return }
        model.deleteHistory(at: IndexSet(integer: idx))
    }
}

