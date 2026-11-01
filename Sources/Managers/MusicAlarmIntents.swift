#if canImport(AppIntents)
import AppIntents
import AppKit

@available(macOS 13.0, *)
struct OpenMusicAlarmIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Music Alarm"
    static var description = IntentDescription("Bring the Music Alarm window to the front.")
    static var openAppWhenRun: Bool { true }

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            (NSApp.delegate as? AppDelegate)?.showMainWindowForIntent()
        }
        return .result()
    }
}

@available(macOS 13.0, *)
struct TestMusicAlarmIntent: AppIntent {
    static var title: LocalizedStringResource = "Test Alarm"
    static var description = IntentDescription("Start the non-persistent Music Alarm test flow.")
    static var openAppWhenRun: Bool { true }

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            (NSApp.delegate as? AppDelegate)?.testAlarmForIntent()
        }
        return .result()
    }
}

@available(macOS 13.0, *)
struct MusicAlarmShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenMusicAlarmIntent(),
            phrases: ["Open Music Alarm in \(.applicationName)"],
            shortTitle: "Open Music Alarm",
            systemImageName: "alarm.fill"
        )
        AppShortcut(
            intent: TestMusicAlarmIntent(),
            phrases: ["Test my alarm in \(.applicationName)"],
            shortTitle: "Test Alarm",
            systemImageName: "play.circle.fill"
        )
    }
}
#endif
