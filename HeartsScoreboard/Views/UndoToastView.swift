import SwiftUI

/// "Round N undone" with a Redo button. Hosted and auto-dismissed by `GameView`.
struct UndoToastView: View {
    let message: String
    let onRedo: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            Text(message)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.primary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: onRedo) {
                Text("Redo")
                    .font(.subheadline.weight(.bold))
                    .padding(.horizontal, 14)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.accent)
            .accessibilityIdentifier("undoToast.redo")
        }
        .padding(.leading, 16)
        .padding(.trailing, 4)
        .padding(.vertical, 2)
        .frame(maxWidth: 420)
        .background(
            Capsule(style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(Color.primary.opacity(colorScheme == .dark ? 0.25 : 0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.25), radius: 10, x: 0, y: 4)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("undoToast")
    }
}
