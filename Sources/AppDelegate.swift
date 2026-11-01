import AppKit
import SwiftUI
import Combine

/// AppKit application delegate. Sets up the main window hosting the SwiftUI
/// content, wires up the data store / audio manager / alarm engine, and builds
/// the minimal main menu.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?
    private var store: AlarmStore!
    private var audioManager: AudioManager!
    private var engine: AlarmEngine!
    private var languageManager = LanguageManager.shared
    private let appSettings = AppSettings.shared
    private var sharedStorageObserver: NSObjectProtocol?
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?
    private let globalShortcutManager = GlobalShortcutManager()
    private var settingsCancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let store = AlarmStore()
        let audio = AudioManager()
        let engine = AlarmEngine(store: store, audioManager: audio)
        self.store = store
        self.audioManager = audio
        self.engine = engine

        // A second copy of the app may update the shared JSON while this copy
        // is inactive. Reload when macOS brings this process back to the front
        // so all app locations converge on the same alarm list.
        sharedStorageObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak store] _ in
            store?.reloadFromSharedStorage()
        }

        // Wire sequential playlist callback: when a local track finishes,
        // advance to the next track in the playlist.
        audio.onTrackFinished = { [weak engine] in
            engine?.advanceToNextTrack()
        }

        AlarmNotificationManager.shared.configure(engine: engine)
        engine.start()
        setupMenu()
        createMainWindow()
        updateMenuBarItem()
        configureGlobalShortcut()
        appSettings.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateMenuBarItem()
                self?.configureGlobalShortcut()
            }
            .store(in: &settingsCancellables)

        NSApp.setActivationPolicy(.regular)
        if appSettings.hideMainWindowOnLaunch {
            window?.orderOut(nil)
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    /// Re-opens the main window when the user clicks the Dock icon / re-activates
    /// the app while no visible window is open (e.g. after clicking the red
    /// close button, which hides the window but keeps the app alive so alarms
    /// can still fire).
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            showMainWindow()
        }
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false // keep running in the background so alarms still fire
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let observer = sharedStorageObserver {
            NotificationCenter.default.removeObserver(observer)
            sharedStorageObserver = nil
        }
        engine?.stop()
        store?.save() // flush any pending alarm/audio changes to disk before exiting
    }

    /// Shows the existing main window, or recreates it if it has been released.
    private func showMainWindow() {
        if let window = window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        createMainWindow()
    }

    /// Builds and shows the main window hosting the SwiftUI content.
    private func createMainWindow() {
        let contentView = ContentView()
            .environmentObject(store)
            .environmentObject(audioManager)
            .environmentObject(engine)
            .environmentObject(languageManager)
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
    }

    private func setupMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)

        let appMenu = NSMenu()
        appMenu.addItem(withTitle: L("About Music Alarm"),
                        action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
                        keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: L("Settings…"),
                        action: #selector(openSettings),
                        keyEquivalent: ",")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: L("Hide Music Alarm"),
                        action: #selector(NSApplication.hide(_:)),
                        keyEquivalent: "h")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: L("Quit Music Alarm"),
                        action: #selector(NSApplication.terminate(_:)),
                        keyEquivalent: "q")
        appMenuItem.submenu = appMenu

        NSApp.mainMenu = mainMenu
    }

    private func configureGlobalShortcut() {
        if appSettings.globalShortcutEnabled {
            globalShortcutManager.start { [weak self] in
                DispatchQueue.main.async { self?.showMainWindow() }
            }
        } else {
            globalShortcutManager.stop()
        }
    }

    private func updateMenuBarItem() {
        if appSettings.showMenuBarItem {
            if statusItem == nil {
                let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
                if #available(macOS 11.0, *) {
                    item.button?.image = NSImage(systemSymbolName: "alarm.fill", accessibilityDescription: L("Music Alarm"))
                } else {
                    item.button?.title = "⏰"
                }
                item.button?.imagePosition = .imageOnly
                let menu = NSMenu()
                menu.addItem(withTitle: L("Open Music Alarm"),
                             action: #selector(showMainWindowFromMenu),
                             keyEquivalent: "")
                menu.addItem(withTitle: L("Settings…"),
                             action: #selector(openSettings),
                             keyEquivalent: "")
                menu.addItem(withTitle: L("Test Alarm"),
                             action: #selector(testAlarmFromMenu),
                             keyEquivalent: "")
                menu.addItem(withTitle: L("Pause today"),
                             action: #selector(pauseTodayFromMenu),
                             keyEquivalent: "")
                menu.addItem(withTitle: L("Resume all alarms"),
                             action: #selector(resumeAllFromMenu),
                             keyEquivalent: "")
                menu.addItem(NSMenuItem.separator())
                menu.addItem(withTitle: L("Quit Music Alarm"),
                             action: #selector(terminateFromMenu),
                             keyEquivalent: "q")
                menu.items.forEach { $0.target = self }
                item.menu = menu
                statusItem = item
            }
        } else if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
            self.statusItem = nil
        }
    }

    @objc private func showMainWindowFromMenu() {
        showMainWindow()
    }

    func showMainWindowForIntent() {
        showMainWindow()
    }

    @objc private func terminateFromMenu() {
        NSApp.terminate(nil)
    }

    @objc func openSettings() {
        if let settingsWindow {
            settingsWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hosting = NSHostingView(rootView: SettingsView(settings: appSettings)
            .environmentObject(store)
            .environmentObject(engine))
        let settingsWindow = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 720, height: 760),
                                       styleMask: [.titled, .closable, .resizable],
                                       backing: .buffered,
                                       defer: false)
        settingsWindow.title = L("Settings")
        settingsWindow.isReleasedWhenClosed = false
        settingsWindow.minSize = NSSize(width: 680, height: 640)
        settingsWindow.contentView = hosting
        settingsWindow.center()
        settingsWindow.makeKeyAndOrderFront(nil)
        self.settingsWindow = settingsWindow
        NSApp.activate(ignoringOtherApps: true)

    }

    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let menu = NSMenu()
        menu.addItem(withTitle: L("Open Music Alarm"), action: #selector(showMainWindowFromMenu), keyEquivalent: "")
        menu.addItem(withTitle: L("Test Alarm"), action: #selector(testAlarmFromMenu), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: L("Pause today"), action: #selector(pauseTodayFromMenu), keyEquivalent: "")
        menu.addItem(withTitle: L("Resume all alarms"), action: #selector(resumeAllFromMenu), keyEquivalent: "")
        menu.items.forEach { $0.target = self }
        return menu
    }

    @objc private func testAlarmFromMenu() {
        engine?.testAlarm()
    }

    func testAlarmForIntent() {
        engine?.testAlarm()
    }

    @objc private func pauseTodayFromMenu() {
        store?.pauseToday()
    }

    @objc private func resumeAllFromMenu() {
        store?.resumeAll()
    }
}
