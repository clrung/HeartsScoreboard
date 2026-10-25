import Foundation

// Derived statistics for finished games. Nothing here is stored; it is all computed from
// `CompletedGame` / `[CompletedGame]` so the persisted format is unchanged.

extension CompletedGame {
    /// One player's running total after each round. `points[0]` is the starting 0 (round 0).
    struct CumulativeSeries: Identifiable, Equatable {
        let id: UUID
        let name: String
        let points: [Int]
    }

    /// Running totals per player in seating order; every series has `roundCount + 1` points.
    var cumulativeSeries: [CumulativeSeries] {
        game.players.map { player in
            var running = 0
            var points = [0]
            for hand in game.hands {
                running += hand.pointsByPlayerID[player.id] ?? 0
                points.append(running)
            }
            return CumulativeSeries(id: player.id, name: player.name, points: points)
        }
    }

    struct BiggestHand: Equatable {
        let playerName: String
        let points: Int
        /// 1-based round number.
        let round: Int
    }

    /// The highest single-hand score by any player (first occurrence wins ties). Nil with no hands.
    var biggestHand: BiggestHand? {
        var best: BiggestHand?
        for (index, hand) in game.hands.enumerated() {
            for player in game.players {
                let points = hand.pointsByPlayerID[player.id] ?? 0
                if best == nil || points > best!.points {
                    best = BiggestHand(playerName: player.name, points: points, round: index + 1)
                }
            }
        }
        return best
    }

    /// Number of hands in which someone shot the moon.
    var moonCount: Int {
        game.hands.filter { hand in
            game.players.contains { game.isMoonHand(hand, for: $0.id) }
        }.count
    }

    /// Number of hands where the 10♦ was recorded (only when the rule was on).
    var tenOfDiamondsCount: Int {
        game.hands.filter { $0.tenOfDiamondsPlayerID != nil }.count
    }

    /// Names of every player tied on the lowest total, in seating order.
    var winnerNames: [String] {
        guard let best = winningScore else { return [] }
        return game.totals().filter { $0.total == best }.map(\.player.name)
    }

    /// Hero sentence: "Deuce won with 54" / "Ace and Deuce tied with 54".
    var heroText: String {
        let names = winnerNames
        guard let score = winningScore, !names.isEmpty else { return String(localized: "No winner") }
        let list = ListFormatter.localizedString(byJoining: names)
        if names.count == 1 {
            return String(format: String(localized: "%@ won with %d"), list, score)
        }
        return String(format: String(localized: "%@ tied with %d"), list, score)
    }

    /// Short rule summary from the game's own settings, e.g. "Ends at 100 · Moon adds 26 · 10♦ = −10".
    var ruleSummary: String {
        var parts = [String(format: String(localized: "Ends at %d"), settings.endingScore)]
        switch settings.shootMoonPreference {
        case .add26: parts.append(String(localized: "Moon adds 26 to others"))
        case .subtract26: parts.append(String(localized: "Moon subtracts 26 from shooter"))
        }
        if settings.tenOfDiamondsMinus10 { parts.append(String(localized: "10♦ = −10")) }
        return parts.joined(separator: " · ")
    }
}

/// Aggregate record for one player name across history.
struct PlayerRecord: Identifiable, Equatable {
    /// Normalized (trimmed, lowercased) name used for matching.
    let id: String
    /// Display name, taken from the most recent game the player appears in.
    let name: String
    let gamesPlayed: Int
    /// Games finished with the lowest total; a tie for lowest counts as a win for each tied player.
    let wins: Int
    let totalScore: Int
    let moons: Int

    var winPercent: Double { gamesPlayed == 0 ? 0 : Double(wins) / Double(gamesPlayed) * 100 }
    var averageScore: Double { gamesPlayed == 0 ? 0 : Double(totalScore) / Double(gamesPlayed) }

    static func normalize(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

private struct Acc { var name: String; var latest: Date; var games = 0; var wins = 0; var total = 0; var moons = 0 }

extension Array where Element == CompletedGame {
    /// Per-player records, best first: wins, then win %, then games played, then name.
    /// Players are matched by trimmed, case-insensitive name; blank names are skipped.
    var playerRecords: [PlayerRecord] {
        var byKey: [String: Acc] = [:]
        for completed in self {
            let best = completed.winningScore
            for player in completed.game.players {
                let key = PlayerRecord.normalize(player.name)
                guard !key.isEmpty else { continue }
                let display = player.name.trimmingCharacters(in: .whitespacesAndNewlines)
                var acc = byKey[key] ?? Acc(name: display, latest: completed.finishedAt)
                if completed.finishedAt >= acc.latest { acc.name = display; acc.latest = completed.finishedAt }
                let total = completed.game.totalPoints(for: player.id)
                acc.games += 1
                acc.total += total
                if total == best { acc.wins += 1 }
                acc.moons += completed.game.hands.filter { completed.game.isMoonHand($0, for: player.id) }.count
                byKey[key] = acc
            }
        }
        return byKey.map { key, a in
            PlayerRecord(id: key, name: a.name, gamesPlayed: a.games, wins: a.wins, totalScore: a.total, moons: a.moons)
        }
        .sorted { l, r in
            if l.wins != r.wins { return l.wins > r.wins }
            if l.winPercent != r.winPercent { return l.winPercent > r.winPercent }
            if l.gamesPlayed != r.gamesPlayed { return l.gamesPlayed > r.gamesPlayed }
            return l.name.localizedCaseInsensitiveCompare(r.name) == .orderedAscending
        }
    }
}
