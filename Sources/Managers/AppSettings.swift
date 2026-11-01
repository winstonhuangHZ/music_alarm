import Foundation
import Combine
import ServiceManagement

/// User-facing application settings that are safe to keep outside the shared
/// alarm data. These settings belong to the local installation/user session.
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published var launchAtLogin: Bool {
        didSet {
            guard launchAtLogin != oldValue else { return }
            applyLaunchAtLogin()
        }
    }

    @Published var hideMainWindowOnLaunch: Bool {
        didSet { UserDefaults.standard.set(hideMainWindowOnLaunch, forKey: Keys.hideOnLaunch) }
    }

    @Published var showMenuBarItem: Bool {
        didSet { UserDefaults.standard.set(showMenuBarItem, forKey: Keys.showMenuBarItem) }
    }

    @Published private(set) var launchAtLoginError: String?

    private enum Keys {
        static let hideOnLaunch = "MusicAlarm.hideMainWindowOnLaunch.v1"
        static let showMenuBarItem = "MusicAlarm.showMenuBarItem.v1"
        static let launchAtLogin = "MusicAlarm.launchAtLogin.v1"
    }

    private init() {
        hideMainWindowOnLaunch = UserDefaults.standard.bool(forKey: Keys.hideOnLaunch)
        showMenuBarItem = UserDefaults.standard.object(forKey: Keys.showMenuBarItem) as? Bool ?? true

        if #available(macOS 13.0, *) {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        } else {
            launchAtLogin = UserDefaults.standard.bool(forKey: Keys.launchAtLogin)
        }
    }

    private func applyLaunchAtLogin() {
        UserDefaults.standard.set(launchAtLogin, forKey: Keys.launchAtLogin)
        if #available(macOS 13.0, *) {
            do {
                if launchAtLogin {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
                launchAtLoginError = nil
            } catch {
                launchAtLoginError = error.localizedDescription
            }
        }
    }
}
