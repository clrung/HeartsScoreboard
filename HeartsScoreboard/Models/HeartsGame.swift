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
    ///
    /// `pointsByPlayerID` holds each player's FINAL points for the hand. When the optional
    /// "10♦ = -10" rule is on, the holder's entry already includes the -10, so totals need no special handling.
    struct Hand: Identifiable, Equatable, Codable {
        let id: UUID
        var pointsByPlayerID: [UUID: Int]
        var notes: String
        var createdAt: Date
        /// Player who took the 10♦ (Omnibus Hearts variant). Nil when the rule was off.
        var tenOfDiamondsPlayerID: UUID? = nil
    }

    /// Points awarded to whoever takes the 10♦ when the optional rule is on.
    static let tenOfDiamondsPoints = -10

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

    /// A player's total over every hand except `handID`; used while editing that round, so the
    /// badges show the standing the edited hand is being added to. An unknown id excludes nothing.
    func totalPoints(for playerID: UUID, excluding handID: UUID?) -> Int {
        hands.reduce(0) { $0 + ($1.id == handID ? 0 : ($1.pointsByPlayerID[playerID] ?? 0)) }
    }

    func totals(excluding handID: UUID?) -> [(player: Player, total: Int)] {
        players.map { ($0, totalPoints(for: $0.id, excluding: handID)) }
    }

    /// Final per-player points for a hand: the hearts/Q♠ penalty points plus the -10 for the 10♦ holder (if any).
    static func finalPoints(
        penaltyPoints: [UUID: Int],
        tenOfDiamondsPlayerID: UUID?
    ) -> [UUID: Int] {
        var result = penaltyPoints
        if let holder = tenOfDiamondsPlayerID {
            result[holder] = (result[holder] ?? 0) + tenOfDiamondsPoints
        }
        return result
    }

    /// Valid Hearts round (hearts/Q♠ points only, 10♦ excluded): total is 26 (split among ≥2 players),
    /// -26, or (players - 1) * 26 (shoot the moon). One player having 26 and the rest 0 is invalid.
    static func isValidRound(penaltyScores: [Int]) -> Bool {
        let n = penaltyScores.count
        guard n > 0 else { return false }
        let sum = penaltyScores.reduce(0, +)
        if sum == 26 {
            return !penaltyScores.contains(26)
        }
        return sum == -26 || sum == (n - 1) * 26
    }

    /// Returns true if the given hand represents a "shoot the moon" outcome for the specified player,
    /// based on the current players and their per-hand points.
    func isMoonHand(_ hand: Hand, for playerID: UUID) -> Bool {
        let n = players.count
        guard n > 0 else { return false }

        // Take the 10♦ bonus back out so the checks below only see hearts/Q♠ points.
        func penaltyScore(for id: UUID) -> Int {
            let score = hand.pointsByPlayerID[id] ?? 0
            return id == hand.tenOfDiamondsPlayerID ? score - Self.tenOfDiamondsPoints : score
        }

        let sum = players.reduce(0) { $0 + penaltyScore(for: $1.id) }
        let playerScore = penaltyScore(for: playerID)

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


extension HeartsGame {
    /// Short column-header labels for crowded scoreboards (6 players in a narrow pane).
    ///
    /// Each label is the uppercased first letter of the first two words ("Mary Ann" -> "MA").
    /// Players whose initials collide use the first two characters of their first word instead
    /// ("Alexandra"/"Andrew" -> "Al"/"An"). Any that still collide fall back to the full name.
    /// A blank name always falls back to itself. Uses `Character`, so emoji and composed characters stay intact.
    static func headerLabels(for names: [String]) -> [String] {
        func words(_ name: String) -> [Substring] { name.split(whereSeparator: \.isWhitespace) }

        let initials = names.map { name -> String? in
            let w = words(name)
            guard !w.isEmpty else { return nil }
            return w.prefix(2).compactMap { $0.first }.map { String($0).uppercased() }.joined()
        }
        var labels = zip(names, initials).map { $1 ?? $0 }

        func collidingIndices(_ values: [String]) -> Set<Int> {
            var seen: [String: [Int]] = [:]
            for (i, v) in values.enumerated() where initials[i] != nil { seen[v, default: []].append(i) }
            return Set(seen.values.filter { $0.count > 1 }.flatMap { $0 })
        }

        let firstPass = collidingIndices(labels)
        for i in firstPass {
            labels[i] = String(words(names[i])[0].prefix(2))
        }
        for i in collidingIndices(labels) {
            labels[i] = names[i]
        }
        return labels
    }
}
