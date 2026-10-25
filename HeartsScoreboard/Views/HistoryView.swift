import SwiftUI
import Observation

struct HistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var model: GameViewModel
    @State private var tab: Tab = .games

    private enum Tab: Hashable { case games, players }

    private var sortedHistory: [CompletedGame] {
        model.history.sorted { $0.finishedAt > $1.finishedAt }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("View", selection: $tab) {
                    Text("Games").tag(Tab.games)
                    Text("Players").tag(Tab.players)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)
                .accessibilityIdentifier("history.tab")

                switch tab {
                case .games: gamesList
                case .players: PlayersLeaderboardView(records: model.history.playerRecords)
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

    private var gamesList: some View {
            List {
                if sortedHistory.isEmpty {
                    ContentUnavailableView(
                        "No Games Yet",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("Finished games will show up here.")
                    )
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(sortedHistory) { game in
                        NavigationLink {
                            HistoryDetailView(completedGame: game)
                        } label: {
                            HistoryRow(game: game, winner: model.winnerDescription(for: game))
                        }
                        .accessibilityIdentifier("history.row")
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                delete(game: game)
                            } label: {
                                Label("Delete", systemImage: "trash")
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


private struct HistoryRow: View {
    let game: CompletedGame
    let winner: String

    private var standings: String {
        game.sortedResults.map { "\($0.name) \($0.total)" }.joined(separator: " · ")
    }

    /// Games from the last week read relatively ("2 hours ago"); older ones show the calendar date.
    private var isRecent: Bool {
        game.finishedAt > Date().addingTimeInterval(-7 * 24 * 60 * 60)
    }

    private var roundsText: String {
        String(format: String(localized: "%d rounds"), game.roundCount)
    }

    private var accessibilitySummary: String {
        var parts = [winner, standings, game.finishedAt.formatted(date: .abbreviated, time: .shortened), roundsText]
        if game.hadMoonShot { parts.append(String(localized: "Shot the moon")) }
        return parts.joined(separator: ", ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: "trophy.fill")
                    .foregroundStyle(Theme.leader)
                    .imageScale(.small)
                Text(winner)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                if let score = game.winningScore {
                    Text("\(score)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                HStack(spacing: 4) {
                    if game.hadMoonShot {
                        Image(systemName: "moon.fill")
                    }
                    Text(roundsText)
                }
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color.secondary.opacity(0.15)))
            }

            Text(standings)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            HStack(spacing: 4) {
                if isRecent {
                    Text(game.finishedAt, format: .relative(presentation: .named))
                } else {
                    Text(game.finishedAt, format: .dateTime.month().day().year())
                }
                Text("·")
                Text(game.finishedAt, format: .dateTime.hour().minute())
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }
}
