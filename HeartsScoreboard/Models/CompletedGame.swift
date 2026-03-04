import Foundation

struct CompletedGame: Identifiable, Codable {
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
        guard let minTotal = totals.map(\.total).min() else { return "No winner" }
        let winners = totals.filter { $0.total == minTotal }.map(\.player.name)
        if winners.isEmpty {
            return "No winner"
        } else if winners.count == 1, let name = winners.first {
            return name
        } else {
            return winners.joined(separator: ", ")
        }
    }
}

