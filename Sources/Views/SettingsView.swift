import SwiftUI
import AppKit

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @EnvironmentObject var store: AlarmStore
    @State private var backupMessage = ""
    @State private var pendingImportURL: URL?
    @State private var showImportConfirmation = false
    @State private var backupPreview: BackupPreview?
    @State private var restorePolicy: BackupConflictPolicy = .replace

    var body: some View {
        Form {
            Section(header: Text(L("Application"))) {
                Toggle(L("Launch Music Alarm at login"), isOn: $settings.launchAtLogin)
                Toggle(L("Hide the main window on launch"), isOn: $settings.hideMainWindowOnLaunch)
                Toggle(L("Show Music Alarm in the menu bar"), isOn: $settings.showMenuBarItem)
                Toggle(L("Copy imported audio into the Music Alarm library"), isOn: $settings.copyImportedAudioToLibrary)
                Picker(L("Fallback sound"), selection: $settings.fallbackSoundChoice) {
                    ForEach(FallbackSoundChoice.allCases) { choice in
                        Text(choice.title).tag(choice)
                    }
                }
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
                diagnosticsView
            }

            Section(header: Text(L("Recent alarm history"))) {
                if store.recentOccurrences(limit: 8).isEmpty {
                    Text(L("No history"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(store.recentOccurrences(limit: 8)) { occurrence in
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(occurrence.label.isEmpty ? L("Alarm") : occurrence.label)
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                Text(occurrence.outcome.title)
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(occurrence.outcome == .failed ? .red : .secondary)
                            }
                            Text(dateString(occurrence.scheduledDate))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            if let reason = occurrence.failureReason, !reason.isEmpty {
                                Text(reason)
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            Section(header: Text(L("Backup and restore"))) {
                HStack {
                    Button(L("Export backup")) {
                        do {
                            let folder = try BackupManager.exportInteractively(store: store)
                            backupMessage = String(format: L("Backup exported to %@"), folder.lastPathComponent)
                        } catch {
                            backupMessage = error.localizedDescription
                        }
                    }
                    Button(L("Import backup")) {
                        let panel = NSOpenPanel()
                        panel.title = L("Choose a Music Alarm backup folder")
                        panel.prompt = L("Choose Backup")
                        panel.canChooseFiles = false
                        panel.canChooseDirectories = true
                        panel.allowsMultipleSelection = false
                        if panel.runModal() == .OK, let url = panel.url {
                            do {
                                backupPreview = try BackupManager.preview(from: url)
                                pendingImportURL = url
                                showImportConfirmation = true
                            } catch {
                                backupMessage = error.localizedDescription
                            }
                        }
                    }
                }
                if !backupMessage.isEmpty {
                    Text(backupMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                Text(L("A restore replaces the current shared alarms and audio library after validation."))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(20)
        .frame(width: 430, height: 560)
        .sheet(isPresented: $showImportConfirmation) {
            VStack(alignment: .leading, spacing: 14) {
                Text(L("Restore backup?"))
                    .font(.headline)
                if let backupPreview {
                    Text(backupPreview.summary)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Picker(L("Conflict handling"), selection: $restorePolicy) {
                    ForEach(BackupConflictPolicy.allCases) { policy in
                        Text(policy.title).tag(policy)
                    }
                }
                Text(L("A merge keeps current records and lets backup records with the same ID replace them."))
                    .font(.caption)
                    .foregroundColor(.secondary)
                HStack {
                    Spacer()
                    Button(L("Cancel")) { showImportConfirmation = false }
                    Button(L("Restore")) {
                      guard let pendingImportURL else { return }
                      do {
                          try BackupManager.importBackup(from: pendingImportURL,
                                                         into: store,
                                                         conflictPolicy: restorePolicy)
                          backupMessage = L("Backup restored")
                          showImportConfirmation = false
                      } catch {
                          backupMessage = error.localizedDescription
                      }
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(20)
            .frame(width: 420)
        }
    }

    private var diagnosticsView: some View {
        let zone = TimeZone.current
        let offset = zone.secondsFromGMT(for: Date())
        let sign = offset >= 0 ? "+" : "-"
        let absoluteOffset = abs(offset)
        let hours = absoluteOffset / 3600
        let minutes = (absoluteOffset % 3600) / 60
        let nextDate = store.nextAlarmFire(at: Date()).date
        return VStack(alignment: .leading, spacing: 3) {
            Text("\(L("Current system time")): \(dateString(Date()))")
            Text("\(L("Time zone")): \(zone.identifier) (UTC\(sign)\(String(format: "%02d:%02d", hours, minutes)))")
            Text("\(L("Daylight saving time")): \(zone.isDaylightSavingTime(for: Date()) ? L("On") : L("Off"))")
            Text("\(L("Next scheduler deadline")): \(nextDate.map(dateString) ?? L("No upcoming alarm"))")
        }
        .font(.caption2)
        .foregroundColor(.secondary)
    }

    private func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}
