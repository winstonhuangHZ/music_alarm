import SwiftUI
import AppKit

/// An `NSViewRepresentable` wrapper around `NSVisualEffectView`.
/// Provides a frosted-glass ("ultra thin material") background on macOS
/// versions whose SwiftUI lacks the `.ultraThinMaterial` modifier.
struct VisualEffectView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.state = .active
        view.material = .hudWindow
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // Nothing to update.
    }
}
