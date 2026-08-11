import AppKit
import SwiftUI

/// AppKit application delegate. Sets up the main window hosting the SwiftUI
/// content, wires up the data store / audio manager / alarm engine, and builds
/// the minimal main menu.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?
    private var store: AlarmStore!
    private var audioManager: AudioManager!
    private var engine: AlarmEngine!

    func applicationDidFinishLaunching(_ notification: Notification) {
        let store = AlarmStore()
        let audio = AudioManager()
        let engine = AlarmEngine(store: store, audioManager: audio)
        self.store = store
        self.audioManager = audio
        self.engine = engine

        engine.start()
        setupMenu()

        let contentView = ContentView()
            .environmentObject(store)
            .environmentObject(audio)
            .environmentObject(engine)
            .frame(minWidth: 760, minHeight: 640)

        let hosting = NSHostingView(rootView: contentView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 840, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Music Alarm"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 760, height: 640)
        window.contentView = hosting
        window.center()
        window.setFrameAutosaveName("MusicAlarmMainWindow")
        window.makeKeyAndOrderFront(nil)
        self.window = window

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false // keep running in the background so alarms still fire
    }

    func applicationWillTerminate(_ notification: Notification) {
        engine?.stop()
    }

    private func setupMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)

        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About Music Alarm",
                        action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
                        keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Hide Music Alarm",
                        action: #selector(NSApplication.hide(_:)),
                        keyEquivalent: "h")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Quit Music Alarm",
                        action: #selector(NSApplication.terminate(_:)),
                        keyEquivalent: "q")
        appMenuItem.submenu = appMenu

        NSApp.mainMenu = mainMenu
    }
}
