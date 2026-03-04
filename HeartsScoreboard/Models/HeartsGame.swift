import Foundation

struct HeartsGame: Equatable, Codable {
    struct Player: Identifiable, Equatable, Codable {
        let id: UUID
        var name: String
    }

    /// Per-hand points in standard Hearts:
    /// - Each heart: 1 point
    /// - Queen of spades: 13 points
    /// Total possible: 26 points
    struct Hand: Identifiable, Equatable, Codable {
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

    /// Returns true if the given hand represents a "shoot the moon" outcome for the specified player,
    /// based on the current players and their per-hand points.
    func isMoonHand(_ hand: Hand, for playerID: UUID) -> Bool {
        let n = players.count
        guard n > 0 else { return false }

        let scores = players.map { hand.pointsByPlayerID[$0.id] ?? 0 }
        let sum = scores.reduce(0, +)
        let playerScore = hand.pointsByPlayerID[playerID] ?? 0

        // Subtract 26 preference: one player at -26, total -26
        if sum == -26, playerScore == -26 {
            return true
        }

        // Add 26 preference: shooter gets 0, all others 26 -> total (n - 1) * 26
        if sum == (n - 1) * 26, playerScore == 0 {
            return true
        }

        return false
    }
}

