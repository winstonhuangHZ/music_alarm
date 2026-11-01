import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        Form {
            Section(header: Text(L("Application"))) {
                Toggle(L("Launch Music Alarm at login"), isOn: $settings.launchAtLogin)
                Toggle(L("Hide the main window on launch"), isOn: $settings.hideMainWindowOnLaunch)
                Toggle(L("Show Music Alarm in the menu bar"), isOn: $settings.showMenuBarItem)
                Toggle(L("Copy imported audio into the Music Alarm library"), isOn: $settings.copyImportedAudioToLibrary)
                VStack(alignment: .leading, spacing: 5) {
                    Text(L("Missed alarm behavior"))
                    Picker(L("Missed alarm behavior"), selection: $settings.missedAlarmPolicy) {
                        ForEach(MissedAlarmPolicy.allCases) { policy in
                            Text(policy.title).tag(policy)
                        }
                    }
                }
                Toggle(L("Enable wake-up confirmation"), isOn: $settings.wakeConfirmationEnabled)
                if settings.wakeConfirmationEnabled {
                    Picker(L("Confirmation deadline"), selection: $settings.wakeConfirmationDeadlineMinutes) {
                        Text(L("No deadline")).tag(Optional<Int>.none)
                        Text(L("5 minutes")).tag(Optional(5))
                        Text(L("10 minutes")).tag(Optional(10))
                        Text(L("30 minutes")).tag(Optional(30))
                        Text(L("60 minutes")).tag(Optional(60))
                    }
                    Picker(L("Confirmation method"), selection: $settings.wakeConfirmationMode) {
                        ForEach(WakeConfirmationMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                }
                if let error = settings.launchAtLoginError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }

            Section(header: Text(L("About reliability"))) {
                Text(L("Music Alarm keeps one running instance so alarm playback is not duplicated when the app is opened from another copy."))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(20)
        .frame(width: 430, height: 390)
    }
}
