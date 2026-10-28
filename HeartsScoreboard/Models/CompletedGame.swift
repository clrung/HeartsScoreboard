import Foundation

struct CompletedGame: Identifiable, Equatable, Codable {
    let id: UUID
    let finishedAt: Date
    let game: HeartsGame
    let settings: GameSettings

    init(id: UUID = UUID(), finishedAt: Date = Date(), game: HeartsGame, settings: GameSettings) {
        self.id = id
        self.finishedAt = finishedAt
        self.game = game
        self.settings = settings
    }

    var winnerDescription: String {
        let totals = game.totals()
        guard let minTotal = totals.map(\.total).min() else { return String(localized: "No winner") }
        let winners = totals.filter { $0.total == minTotal }.map(\.player.name)
        if winners.isEmpty {
            return String(localized: "No winner")
        } else if winners.count == 1, let name = winners.first {
            return name
        } else {
            return winners.joined(separator: ", ")
        }
    }
}

extension CompletedGame {
    /// One player's final standing, used by the history list.
    struct PlayerResult: Equatable {
        let name: String
        let total: Int
    }

    /// Final totals ordered best to worst (lowest score first). Ties keep seating order.
    var sortedResults: [PlayerResult] {
        game.totals()
            .enumerated()
            .sorted { lhs, rhs in
                lhs.element.total != rhs.element.total
                    ? lhs.element.total < rhs.element.total
                    : lhs.offset < rhs.offset
            }
            .map { PlayerResult(name: $0.element.player.name, total: $0.element.total) }
    }

    /// The winning (lowest) total, shared by every tied winner. Nil when there are no players.
    var winningScore: Int? {
        game.totals().map(\.total).min()
    }

    var roundCount: Int { game.hands.count }

    /// True if any player shot the moon in any hand.
    var hadMoonShot: Bool {
        game.hands.contains { hand in
            game.players.contains { game.isMoonHand(hand, for: $0.id) }
        }
    }
}
