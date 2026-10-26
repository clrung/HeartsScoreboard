import SwiftUI

/// The one place VoiceOver announcements are posted, so they all behave alike: high priority, so a
/// sheet dismissing or focus moving right after an action doesn't cut the message off.
enum Announcer {
    static func post(_ message: String) {
        var text = AttributedString(message)
        text.accessibilitySpeechAnnouncementPriority = .high
        AccessibilityNotification.Announcement(text).post()
    }
}

/// Card surface for the scoreboard on the felt: a translucent material over the card color, or the
/// solid card color when Reduce Transparency is on.
struct FeltCardSurface: View {
    let cornerRadius: CGFloat
    let colorScheme: ColorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if reduceTransparency {
            shape.fill(Theme.scoreboardCard(for: colorScheme))
        } else {
            shape
                .fill(.ultraThinMaterial)
                .background(shape.fill(Theme.scoreboardCard(for: colorScheme).opacity(colorScheme == .dark ? 0.9 : 0.85)))
        }
    }
}

/// Look for the round icon buttons on the felt (History, Settings): a translucent white capsule, or a
/// solid system-background capsule with a strong outline under Increase Contrast / Reduce Transparency.
struct FeltIconButtonLook: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private var isSolid: Bool { contrast == .increased || reduceTransparency }

    func body(content: Content) -> some View {
        content
            .padding(8)
            .background {
                Capsule(style: .continuous)
                    .fill(isSolid ? AnyShapeStyle(Color(.systemBackground)) : AnyShapeStyle(Color.white.opacity(colorScheme == .dark ? 0.18 : 0.3)))
            }
            .overlay {
                Capsule(style: .continuous)
                    .stroke(
                        isSolid ? Color.primary.opacity(0.7) : Color.white.opacity(colorScheme == .dark ? 0.4 : 0.6),
                        lineWidth: isSolid ? 1.5 : 0.5
                    )
            }
            .contentShape(.hoverEffect, Capsule(style: .continuous))
            .hoverEffect()
    }
}

/// Small circular icon-button look for controls on the light/dark panel (not the felt), e.g. the
/// round-entry Reset. Uses primary-tinted fills so it reads in both appearances.
struct PanelIconButtonLook: ViewModifier {
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let isEnabled: Bool

    private var isSolid: Bool { contrast == .increased || reduceTransparency }

    func body(content: Content) -> some View {
        content
            .foregroundStyle(isEnabled ? Color.primary : Color.secondary)
            .frame(minWidth: 18, minHeight: 18)
            .padding(7)
            .background {
                Circle().fill(isSolid ? AnyShapeStyle(Color(.systemBackground)) : AnyShapeStyle(Color.primary.opacity(isEnabled ? 0.12 : 0.06)))
            }
            .overlay {
                Circle().stroke(Color.primary.opacity(isSolid ? 0.7 : (isEnabled ? 0.4 : 0.25)), lineWidth: isSolid ? 1.5 : (isEnabled ? 1 : 0.75))
            }
            .contentShape(Circle())
            .contentShape(.hoverEffect, Circle())
            .hoverEffect()
    }
}

extension View {
    func panelIconButtonLook(isEnabled: Bool = true) -> some View { modifier(PanelIconButtonLook(isEnabled: isEnabled)) }
    func feltIconButtonLook() -> some View { modifier(FeltIconButtonLook()) }
}

/// Repeat timing for press-and-hold steppers, separate from the view so it can be tested.
enum HoldRepeat {
    /// Waits `initialDelay`, then calls `action` every `interval` (every `fastInterval` after
    /// `fastAfter` repeats) until the task is cancelled. Returns immediately when cancelled early.
    @MainActor
    static func run(
        initialDelay: Duration = .milliseconds(450),
        interval: Duration = .milliseconds(120),
        fastInterval: Duration = .milliseconds(60),
        fastAfter: Int = 10,
        action: @MainActor () -> Void
    ) async {
        do { try await Task.sleep(for: initialDelay) } catch { return }
        var count = 0
        while !Task.isCancelled {
            action()
            count += 1
            do { try await Task.sleep(for: count >= fastAfter ? fastInterval : interval) } catch { return }
        }
    }
}

/// A button that also repeats its action while held down (press-and-hold on the +/- steppers).
/// A plain tap still acts once, and VoiceOver / Switch Control activate it as an ordinary button,
/// so the repeat is a shortcut and never the only way to change a value. The repeat stops when
/// the finger lifts or slides away, or the button becomes disabled (e.g. the round reached 26).
struct HoldRepeatButton<Label: View>: View {
    let action: () -> Void
    @ViewBuilder let label: () -> Label

    @Environment(\.isEnabled) private var isEnabled
    @State private var repeatTask: Task<Void, Never>?
    /// Set once a repeat fired, so the tap that ends the hold doesn't add one more step.
    @State private var didRepeat = false
    @GestureState private var isPressing = false

    var body: some View {
        Button {
            if didRepeat { didRepeat = false } else { action() }
        } label: {
            label()
        }
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 60, maximumDistance: 24)
                .updating($isPressing) { value, state, _ in state = value }
        )
        .onChange(of: isPressing) { _, pressing in
            if pressing { start() } else { stop() }
        }
        .onChange(of: isEnabled) { _, enabled in
            if !enabled { stop() }
        }
        .onDisappear { stop() }
    }

    private func start() {
        stop()
        didRepeat = false
        repeatTask = Task { @MainActor in
            await HoldRepeat.run {
                didRepeat = true
                action()
            }
        }
    }

    private func stop() {
        repeatTask?.cancel()
        repeatTask = nil
    }
}
