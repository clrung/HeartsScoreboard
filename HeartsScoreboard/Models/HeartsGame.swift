import Foundation

struct HeartsGame: Equatable {
    struct Player: Identifiable, Equatable {
        let id: UUID
        var name: String
    }

    /// Per-hand points in standard Hearts:
    /// - Each heart: 1 point
    /// - Queen of spades: 13 points
    /// Total possible: 26 points
    struct Hand: Identifiable, Equatable {
        let id: UUID
        var pointsByPlayerID: [UUID: Int]
        var notes: String
        var createdAt: Date
    }

    var id: UUID
    var players: [Player]
    var hands: [Hand]

    init(
        id: UUID = UUID(),
        players: [Player],
        hands: [Hand] = []
    ) {
        self.id = id
        self.players = players
        self.hands = hands
    }

    func totalPoints(for playerID: UUID) -> Int {
        hands.reduce(0) { $0 + ( $1.pointsByPlayerID[playerID] ?? 0 ) }
    }

    func totals() -> [(player: Player, total: Int)] {
        players.map { ($0, totalPoints(for: $0.id)) }
    }
}

