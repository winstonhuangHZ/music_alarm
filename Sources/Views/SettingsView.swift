import SwiftUI
import AppKit

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @EnvironmentObject var store: AlarmStore
    @EnvironmentObject var engine: AlarmEngine
    @State private var backupMessage = ""
    @State private var pendingImportURL: URL?
    @State private var showImportConfirmation = false
    @State private var backupPreview: BackupPreview?
    @State private var restorePolicy: BackupConflictPolicy = .replace

    private let labelColumnWidth: CGFloat = 220
    private let controlColumnWidth: CGFloat = 300

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                settingsSection(title: L("Application"), systemImage: "gearshape") {
                    settingRow(L("Launch Music Alarm at login")) {
                        Toggle("", isOn: $settings.launchAtLogin)
                            .labelsHidden()
                            .toggleStyle(CheckboxToggleStyle())
                    }
                    settingRow(L("Hide the main window on launch")) {
                        Toggle("", isOn: $settings.hideMainWindowOnLaunch)
                            .labelsHidden()
                            .toggleStyle(CheckboxToggleStyle())
                    }
                    settingRow(L("Show Music Alarm in the menu bar")) {
                        Toggle("", isOn: $settings.showMenuBarItem)
                            .labelsHidden()
                            .toggleStyle(CheckboxToggleStyle())
                    }
                    settingRow(L("Copy imported audio into the Music Alarm library")) {
                        Toggle("", isOn: $settings.copyImportedAudioToLibrary)
                            .labelsHidden()
                            .toggleStyle(CheckboxToggleStyle())
                    }
                    settingRow(L("Theme")) {
                        Picker("", selection: $settings.themeChoice) {
                            ForEach(ThemeChoice.allCases) { choice in
                                Text(choice.title).tag(choice)
                            }
                        }
                        .labelsHidden()
                    }
                    settingRow(L("Fallback sound")) {
                        Picker("", selection: $settings.fallbackSoundChoice) {
                            ForEach(FallbackSoundChoice.allCases) { choice in
                                Text(choice.title).tag(choice)
                            }
                        }
                        .labelsHidden()
                    }
                    settingRow(L("Missed alarm behavior")) {
                        Picker("", selection: $settings.missedAlarmPolicy) {
                            ForEach(MissedAlarmPolicy.allCases) { policy in
                                Text(policy.title).tag(policy)
                            }
                        }
                        .labelsHidden()
                    }
                    settingRow(L("Enable wake-up confirmation")) {
                        Toggle("", isOn: $settings.wakeConfirmationEnabled)
                            .labelsHidden()
                            .toggleStyle(CheckboxToggleStyle())
                    }
                    if settings.wakeConfirmationEnabled {
                        settingRow(L("Confirmation deadline")) {
                            Picker("", selection: $settings.wakeConfirmationDeadlineMinutes) {
                                Text(L("No deadline")).tag(Optional<Int>.none)
                                Text(L("5 minutes")).tag(Optional(5))
                                Text(L("10 minutes")).tag(Optional(10))
                                Text(L("30 minutes")).tag(Optional(30))
                                Text(L("60 minutes")).tag(Optional(60))
                            }
                            .labelsHidden()
                        }
                        settingRow(L("Confirmation method")) {
                            Picker("", selection: $settings.wakeConfirmationMode) {
                                ForEach(WakeConfirmationMode.allCases) { mode in
                                    Text(mode.title).tag(mode)
                                }
                            }
                            .labelsHidden()
                        }
                    }
                    if let error = settings.launchAtLoginError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                settingsSection(title: L("About reliability"), systemImage: "checkmark.shield") {
                    Text(L("Music Alarm keeps one running instance so alarm playback is not duplicated when the app is opened from another copy."))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    diagnosticsView
                }

                settingsSection(title: L("Recent alarm history"), systemImage: "clock.arrow.circlepath") {
                    recentHistoryView
                }

                settingsSection(title: L("Backup and restore"), systemImage: "externaldrive") {
                    HStack(spacing: 10) {
                        Button {
                            do {
                                let folder = try BackupManager.exportInteractively(store: store)
                                backupMessage = String(format: L("Backup exported to %@"), folder.lastPathComponent)
                            } catch {
                                backupMessage = error.localizedDescription
                            }
                        } label: {
                            Label(L("Export backup"), systemImage: "square.and.arrow.up")
                        }

                        Button {
                            importBackup()
                        } label: {
                            Label(L("Import backup"), systemImage: "square.and.arrow.down")
                        }
                    }
                    .buttonStyle(BorderedButtonStyle())

                    if !backupMessage.isEmpty {
                        Text(backupMessage)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text(L("A restore replaces the current shared alarms and audio library after validation."))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minWidth: 680, idealWidth: 720, minHeight: 640, idealHeight: 760)
        .preferredColorScheme(AppThemePalette.palette(for: settings.themeChoice).colorScheme)
        .sheet(isPresented: $showImportConfirmation) {
            restoreConfirmation
        }
    }

    @ViewBuilder
    private func settingsSection<Content: View>(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.title3.weight(.semibold))

            VStack(alignment: .leading, spacing: 10, content: content)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.72))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.secondary.opacity(0.16), lineWidth: 1)
                )
        }
    }

    @ViewBuilder
    private func settingRow<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .center, spacing: 16) {
            Text(title)
                .frame(width: labelColumnWidth, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

            content()
                .frame(width: controlColumnWidth, alignment: .trailing)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var recentHistoryView: some View {
        Group {
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
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private var restoreConfirmation: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L("Restore backup?"))
                .font(.headline)
            if let backupPreview {
                Text(backupPreview.summary)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Picker(L("Conflict handling"), selection: $restorePolicy) {
                ForEach(BackupConflictPolicy.allCases) { policy in
                    Text(policy.title).tag(policy)
                }
            }
            Text(L("A merge keeps current records and lets backup records with the same ID replace them."))
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button(L("Cancel")) { showImportConfirmation = false }
                Button(L("Restore")) {
                    guard let pendingImportURL else { return }
                    do {
                        try BackupManager.importBackup(
                            from: pendingImportURL,
                            into: store,
                            conflictPolicy: restorePolicy
                        )
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
        .frame(width: 460)
    }

    private func importBackup() {
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
            if !engine.lastDiagnostic.isEmpty {
                Text("\(L("Last engine event")): \(engine.lastDiagnostic)")
            }
        }
        .font(.caption2)
        .foregroundColor(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}
