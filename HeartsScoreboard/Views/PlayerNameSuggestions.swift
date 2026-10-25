import Foundation

/// Suggests player names from finished games so people don't retype the same group every time.
enum PlayerNameSuggestions {
    /// Unique names from `history` (which is most recent first), most recently played first,
    /// skipping blanks, default "Player N" placeholders, and anyone in `excluding`.
    /// Names compare case- and whitespace-insensitively; the first spelling seen (most recent) wins.
    static func suggestions(from history: [CompletedGame], excluding current: [String], limit: Int = 8) -> [String] {
        var seen = Set(current.map(normalize))
        var result: [String] = []
        for completed in history {
            for player in completed.game.players {
                let name = player.name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty, !isPlaceholder(name) else { continue }
                if seen.insert(normalize(name)).inserted {
                    result.append(name)
                    if result.count == limit { return result }
                }
            }
        }
        return result
    }

    /// True for blank names and the auto-generated "Player N" style names.
    static func isPlaceholder(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return true }
        return trimmed.range(of: #"^Player \d+$"#, options: [.regularExpression, .caseInsensitive]) != nil
    }

    private static func normalize(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

extension GameViewModel {
    /// Past-player names not already at the table.
    func suggestedPlayerNames(limit: Int = 8) -> [String] {
        PlayerNameSuggestions.suggestions(from: history, excluding: game.players.map(\.name), limit: limit)
    }

    /// Seats `name`: fills the first placeholder ("Player N" or blank) seat, otherwise adds a new
    /// player (up to 6). Returns false when the table is full and no seat is a placeholder.
    @discardableResult
    func useSuggestedPlayerName(_ name: String) -> Bool {
        if let index = game.players.firstIndex(where: { PlayerNameSuggestions.isPlaceholder($0.name) }) {
            game.players[index].name = name
            return true
        }
        guard game.players.count < 6 else { return false }
        addPlayer()
        game.players[game.players.count - 1].name = name
        return true
    }
}
