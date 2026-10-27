import SwiftUI
import UIKit

/// Applies the in-app Appearance preference to the whole window via `overrideUserInterfaceStyle`.
/// UIKit propagates that to the board and to every presented sheet at once, live, and `.unspecified`
/// goes back to following the device. (SwiftUI's `.preferredColorScheme` at the root plus another on the
/// Settings sheet competed: the sheet turned dark but the board behind it did not.)
struct WindowAppearanceApplier: UIViewRepresentable {
    let style: UIUserInterfaceStyle

    func makeUIView(context: Context) -> ApplierView { ApplierView() }
    func updateUIView(_ uiView: ApplierView, context: Context) {
        uiView.style = style
        uiView.apply()
    }

    final class ApplierView: UIView {
        var style: UIUserInterfaceStyle = .unspecified
        private var applied: UIUserInterfaceStyle?
        override init(frame: CGRect) {
            super.init(frame: frame)
            isUserInteractionEnabled = false
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            applied = nil
            apply()
        }

        func apply() {
            guard let window, style != applied else { return }
            // A fresh window already follows the system; don't clobber a style someone else set on it
            // (the snapshot tests force one) until the preference actually asks for an override.
            if applied != nil || style != .unspecified {
                window.overrideUserInterfaceStyle = style
            }
            applied = style
        }
    }
}

#if DEBUG
/// Test hook: an invisible element whose accessibility value is the board view's *effective*
/// interface style ("dark" / "light"), so a UI test can assert what the board really renders with
/// while Settings is open. It sits in the board's view tree, not in the presented sheet.
struct BoardStyleProbe: UIViewRepresentable {
    func makeUIView(context: Context) -> ProbeView { ProbeView() }
    func updateUIView(_ uiView: ProbeView, context: Context) { uiView.refresh() }

    final class ProbeView: UIView {
        override init(frame: CGRect) {
            super.init(frame: frame)
            isAccessibilityElement = true
            accessibilityIdentifier = "appearance.boardStyle"
            registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: ProbeView, _) in view.refresh() }
            refresh()
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

        func refresh() {
            accessibilityValue = traitCollection.userInterfaceStyle == .dark ? "dark" : "light"
        }
    }
}
#endif
