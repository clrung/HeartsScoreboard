import SwiftUI

/// Per-player records across all finished games (derived from history; nothing stored).
struct PlayersLeaderboardView: View {
    let records: [PlayerRecord]

    var body: some View {
        List {
            if records.isEmpty {
                ContentUnavailableView(
                    "No Players Yet",
                    systemImage: "person.3",
                    description: Text("Player records appear after your first finished game.")
                )
                .listRowBackground(Color.clear)
            } else {
                Section {
                    ForEach(Array(records.enumerated()), id: \.element.id) { index, record in
                        PlayerRecordRow(rank: index + 1, record: record)
                    }
                } footer: {
                    Text("Players are matched by name. Ties for the lowest score count as a win for each tied player.")
                }
            }
        }
        .accessibilityIdentifier("history.players")
    }
}

private struct PlayerRecordRow: View {
    let rank: Int
    let record: PlayerRecord

    private var winPercentText: String {
        record.winPercent.formatted(.number.precision(.fractionLength(0))) + "%"
    }

    private var averageText: String {
        record.averageScore.formatted(.number.precision(.fractionLength(0...1)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(rank)")
                    .font(.subheadline.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 22, alignment: .leading)
                Text(record.name)
                    .font(.headline)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text(winPercentText)
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(Theme.accent)
            }
            HStack(spacing: 0) {
                stat(String(localized: "Played"), "\(record.gamesPlayed)")
                stat(String(localized: "Wins"), "\(record.wins)")
                stat(String(localized: "Avg score"), averageText)
                stat(String(localized: "Moons"), "\(record.moons)")
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(record.name), "
            + String(format: String(localized: "%d wins in %d games"), record.wins, record.gamesPlayed)
            + ", \(winPercentText), "
            + String(localized: "Avg score") + " \(averageText), "
            + String(localized: "Moons") + " \(record.moons)"
        )
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }
}
