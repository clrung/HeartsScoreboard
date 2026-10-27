import SwiftUI
import UIKit

/// Invisible view that becomes first responder and calls `onShake` when the device is shaken.
struct ShakeDetectorView: UIViewControllerRepresentable {
    var onShake: () -> Void
    /// Hardware-key hook: the detector is the window's first responder, so SwiftUI's own focus/`onKeyPress`
    /// never sees plain keys while it holds that role. Return true to consume the key.
    var onKey: ((UIKey) -> Bool)?
    /// Bump this value to ask the detector to reclaim first responder (e.g. after a sheet or alert
    /// dismisses). SwiftUI sheets don't reliably deliver viewDidAppear to the presenting controller,
    /// so nothing else restores it.
    var refocusToken: Int = 0

    func makeUIViewController(context: Context) -> ShakeDetectorViewController {
        let vc = ShakeDetectorViewController(onShake: onShake)
        context.coordinator.lastToken = refocusToken
        return vc
    }

    func updateUIViewController(_ uiViewController: ShakeDetectorViewController, context: Context) {
        uiViewController.onShake = onShake
        uiViewController.onKey = onKey
        if context.coordinator.lastToken != refocusToken {
            context.coordinator.lastToken = refocusToken
            uiViewController.refocus()
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var lastToken = 0
    }
}

final class ShakeDetectorViewController: UIViewController {
    var onShake: () -> Void
    var onKey: ((UIKey) -> Bool)?

    init(onShake: @escaping () -> Void) {
        self.onShake = onShake
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var canBecomeFirstResponder: Bool { true }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        becomeFirstResponder()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        resignFirstResponder()
    }

    /// Reclaims first responder. Tries now, then again after a sheet/alert dismissal animation
    /// has had time to finish (the dismissing controller can still hold first responder until then).
    func refocus() {
        reclaimFirstResponder()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.reclaimFirstResponder()
        }
    }

    func reclaimFirstResponder() {
        guard view.window != nil, !isFirstResponder else { return }
        becomeFirstResponder()
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        var unhandled = presses
        for press in presses {
            if let key = press.key, onKey?(key) == true { unhandled.remove(press) }
        }
        if !unhandled.isEmpty { super.pressesBegan(unhandled, with: event) }
    }

    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        guard motion == .motionShake else { return }
        onShake()
    }
}
