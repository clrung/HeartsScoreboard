import Foundation
import UIKit

/// Hardware-keyboard model for the round-entry panel: which player row is selected, a two-digit buffer for
/// typed values, and the rules each key follows. Pure value type so the key map is unit tested without a view.
///
/// Key map (wired in `RoundInputView`): up/down/Tab move the selection; digits type the value; + / = and -
/// adjust by 1; Q gives the Q♠, M shoots the moon, R takes the rest; Delete/Backspace sets 0.
/// Every rule mirrors the on-screen control it stands for (a chip or stepper that is disabled ignores the key).
struct RoundEntryKeyboard: Equatable {
    enum Command: Equatable {
        case move(Int)
        case digit(Int)
        case adjust(Int)
        case queen
        case moon
        case rest
        case clear
    }

    enum Special { case up, down, tab, delete }

    /// Maps a key to a command. `characters` are the unmodified characters; ⌘/⌃/⌥ combinations are never
    /// ours (they belong to the app's shortcuts), as are keys with no meaning here.
    static func command(characters: String, special: Special?, shift: Bool, hasShortcutModifier: Bool) -> Command? {
        guard !hasShortcutModifier else { return nil }
        switch special {
        case .up: return .move(-1)
        case .down: return .move(1)
        case .tab: return .move(shift ? -1 : 1)
        case .delete: return .clear
        case nil: break
        }
        guard characters.count == 1, let ch = characters.first else { return nil }
        if ch.isASCII, let d = ch.wholeNumberValue { return .digit(d) }
        switch ch {
        case "+", "=": return .adjust(1)
        case "-", "\u{2212}", "_": return .adjust(-1)
        case "q", "Q": return .queen
        case "m", "M": return .moon
        case "r", "R": return .rest
        default: return nil
        }
    }

    /// UIKit key (the shake detector's responder-chain hook).
    static func command(for key: UIKey) -> Command? {
        let special: Special?
        switch key.keyCode {
        case .keyboardUpArrow: special = .up
        case .keyboardDownArrow: special = .down
        case .keyboardTab: special = .tab
        case .keyboardDeleteOrBackspace, .keyboardDeleteForward: special = .delete
        default: special = nil
        }
        let flags = key.modifierFlags
        return command(characters: key.charactersIgnoringModifiers, special: special, shift: flags.contains(.shift),
                       hasShortcutModifier: !flags.isDisjoint(with: [.command, .control, .alternate]))
    }

    /// A typed number is dropped after this long without another digit.
    static let digitTimeout: TimeInterval = 1.0

    var selectedIndex = 0
    /// False until a key has been used, so touch users never see the selection ring.
    var isActive = false
    private var digitCount = 0
    private var digitValue = 0
    private var lastDigitAt: Date?

    init(selectedIndex: Int = 0, isActive: Bool = false) {
        self.selectedIndex = selectedIndex
        self.isActive = isActive
    }

    /// The selected player's id (the index is clamped, players can change under an open panel).
    func selectedPlayerID(players: [HeartsGame.Player]) -> UUID? {
        guard !players.isEmpty else { return nil }
        return players[min(max(0, selectedIndex), players.count - 1)].id
    }

    mutating func clearBuffer() {
        digitCount = 0
        digitValue = 0
        lastDigitAt = nil
    }

    /// Applies one key. Returns true when the key was consumed (even if the rules made it a no-op).
    @discardableResult
    mutating func apply(_ command: Command, to entry: inout RoundEntryState, players: [HeartsGame.Player],
                        preference: ShootMoonPreference, now: Date = Date()) -> Bool {
        guard !players.isEmpty else { return false }
        isActive = true
        selectedIndex = min(max(0, selectedIndex), players.count - 1)

        if case .move(let delta) = command {
            selectedIndex = ((selectedIndex + delta) % players.count + players.count) % players.count
            clearBuffer()
            return true
        }

        let id = players[selectedIndex].id
        let valid = entry.isRoundValid(players: players)
        let moonRound = entry.isShootTheMoon(players: players)

        if case .digit(let d) = command {
            guard !moonRound else { return true }
            let fresh = digitCount == 0 || digitCount >= 2
                || lastDigitAt.map { now.timeIntervalSince($0) > Self.digitTimeout } ?? true
            if fresh {
                digitValue = d
                digitCount = 1
            } else {
                digitValue = digitValue * 10 + d
                digitCount += 1
            }
            lastDigitAt = now
            entry.setPoints(for: id, to: digitValue)
            return true
        }

        clearBuffer()
        switch command {
        case .adjust(let delta):
            if delta > 0 ? !valid : !moonRound { entry.adjustPoints(for: id, delta: delta) }
        case .queen:
            if !moonRound { entry.addQueenOfSpades(for: id) }
        case .moon:
            if !valid { entry.applyShootMoon(shooterID: id, players: players, preference: preference) }
        case .rest:
            if !valid { entry.addRemainingPoints(for: id, players: players) }
        case .clear:
            if !moonRound { entry.setPoints(for: id, to: 0) }
        case .move, .digit:
            break
        }
        return true
    }
}

extension GameViewModel {
    /// Changes whenever the round list or the players change (submit, undo, redo, new game, iCloud sync), and
    /// not for anything else, so the inline entry (owned by `GameView`) can drop its pending values then.
    struct EntryResetKey: Equatable {
        let handIDs: [UUID]
        let playerIDs: [UUID]
    }

    var entryResetKey: EntryResetKey {
        EntryResetKey(handIDs: game.hands.map(\.id), playerIDs: game.players.map(\.id))
    }
}
