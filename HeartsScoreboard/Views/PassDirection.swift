import SwiftUI

/// Which way cards are passed this round. Rendered with SF Symbols (not glyphs in strings) so it
/// reads well in VoiceOver and with right-to-left layouts.
enum PassDirection: Equatable {
    case left, right, across, hold

    /// Odd player counts cycle Left, Right, Hold; even counts cycle Left, Right, Across, Hold.
    static func forPhase(_ phase: Int, playerCount: Int) -> PassDirection {
        if playerCount % 2 == 1 {
            switch phase {
            case 0: return .left
            case 1: return .right
            default: return .hold
            }
        }
        switch phase {
        case 0: return .left
        case 1: return .right
        case 2: return .across
        default: return .hold
        }
    }

    var symbolName: String {
        switch self {
        case .left: return "arrow.left"
        case .right: return "arrow.right"
        case .across: return "arrow.left.arrow.right"
        case .hold: return "hand.raised.fill"
        }
    }

    var title: LocalizedStringKey {
        switch self {
        case .left: return "Left"
        case .right: return "Right"
        case .across: return "Across"
        case .hold: return "Hold"
        }
    }

    /// Spoken form; reuses the keys the status text already localizes.
    var spokenTitle: LocalizedStringKey {
        switch self {
        case .left: return "Pass to the Left"
        case .right: return "Pass to the Right"
        case .across: return "Pass Across"
        case .hold: return "Hold on Tight!"
        }
    }
}

/// Capsule chip on the felt: arrow/hand symbol plus the direction word.
struct PassDirectionChip: View {
    let direction: PassDirection
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        // Full word when it fits; otherwise the arrow alone (the spoken title stays the accessibility label)
        // rather than a truncated "L…".
        ViewThatFits(in: .horizontal) {
            Label {
                Text(direction.title)
            } icon: {
                Image(systemName: direction.symbolName)
            }
            .labelStyle(.titleAndIcon)
            .fixedSize(horizontal: true, vertical: false)
            Image(systemName: direction.symbolName)
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(Color.white)
        .lineLimit(1)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule(style: .continuous).fill(Color.black.opacity(contrast == .increased ? 0.55 : (colorScheme == .dark ? 0.3 : 0.22))))
        .overlay(Capsule(style: .continuous).stroke(Color.white.opacity(0.45), lineWidth: 0.5))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(direction.spokenTitle))
        .accessibilityIdentifier("passDirectionChip")
    }
}
