import AppKit
import SwiftUI

/// Borderless panel that can become key so the popup buttons are usable.
final class AlarmPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// Manages the always-on-top alarm popup window (screen-saver level).
final class AlarmPopupController {
    private static var panel: AlarmPanel?

    static func show(alarm: AlarmItem,
                     onSnooze: @escaping (AlarmItem) -> Void,
                     onStop: @escaping (AlarmItem) -> Void,
                     onConfirmWake: @escaping (AlarmItem) -> Void,
                     showsPlaybackActions: Bool = true) {
        dismiss()

        let contentView = AlarmPopupView(alarm: alarm,
                                         onSnooze: onSnooze,
                                         onStop: onStop,
                                         onConfirmWake: onConfirmWake,
                                         showsPlaybackActions: showsPlaybackActions)
        let hosting = NSHostingView(rootView: contentView)
        let height: CGFloat = showsPlaybackActions ? 480 : 600
        hosting.frame = NSRect(x: 0, y: 0, width: 524, height: height)

        let panel = AlarmPanel(
            contentRect: NSRect(x: 0, y: 0, width: 524, height: height),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.level = .screenSaver
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = hosting
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        AlarmPopupController.panel = panel
    }

    static func dismiss() {
        panel?.orderOut(nil)
        panel = nil
    }
}
