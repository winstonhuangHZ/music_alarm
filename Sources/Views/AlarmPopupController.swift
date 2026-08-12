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
                     onStop: @escaping (AlarmItem) -> Void) {
        dismiss()

        let contentView = AlarmPopupView(alarm: alarm, onSnooze: onSnooze, onStop: onStop)
        let hosting = NSHostingView(rootView: contentView)
        hosting.frame = NSRect(x: 0, y: 0, width: 524, height: 430)

        let panel = AlarmPanel(
            contentRect: NSRect(x: 0, y: 0, width: 524, height: 430),
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
