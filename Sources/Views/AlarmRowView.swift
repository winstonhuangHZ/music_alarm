import SwiftUI

/// One alarm card in the list: time, repeat info, track summary, enable toggle,
/// and a context menu with preview / delete.
struct AlarmRowView: View {
    @EnvironmentObject var store: AlarmStore
    @EnvironmentObject var audioManager: AudioManager
    @EnvironmentObject var languageManager: LanguageManager
    @ObservedObject private var settings = AppSettings.shared

    let alarm: AlarmItem
    let onEdit: (AlarmItem) -> Void
    let onDelete: (AlarmItem) -> Void

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                if !alarm.label.isEmpty {
                    Text(alarm.label)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Text(alarm.timeString)
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .foregroundColor(alarm.isEnabled ? Color.primary : Color.secondary)
                HStack(spacing: 6) {
                    Text(repeatIcon(for: alarm.repeatType))
                        .font(.system(size: 11))
                    Text(alarm.repeatText)
                        .font(.caption)
                    if alarm.snoozeUntil != nil {
                        Text(L("• Snoozed"))
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    if alarm.requiresWakeConfirmation && settings.wakeConfirmationEnabled {
                        Text(wakeConfirmationLabel)
                            .font(.caption)
                            .foregroundColor(wakeConfirmationColor)
                    }
                }
                .foregroundColor(.secondary)
                if alarm.requiresWakeConfirmation && settings.wakeConfirmationEnabled {
                    wakeTimingView
                }
            }

            Spacer()

            HStack(spacing: 6) {
                Text(alarm.hasSound ? alarm.sourceSummary : "⚠️")
                    .foregroundColor(alarm.hasSound ? Color(NSColor.controlAccentColor) : Color.orange)
                Text(alarm.audioDisplayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: 180, alignment: .trailing)

            Button(action: { self.onEdit(self.alarm) }) {
                Text("✏️")
                    .font(.system(size: 14))
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel(L("Edit Alarm"))

            if alarm.requiresWakeConfirmation && settings.wakeConfirmationEnabled && isAwaitingWakeConfirmation {
                Button(action: { self.store.confirmWake(id: self.alarm.id) }) {
                    Text(L("Confirm wake-up"))
                        .font(.caption)
                        .foregroundColor(.green)
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityLabel(L("Confirm wake-up"))
            }

            Toggle(isOn: enabledBinding) {
                Text("")
            }
            .labelsHidden()
            .toggleStyle(SwitchToggleStyle())
            .accessibilityLabel(alarm.isEnabled ? L("Disable alarm") : L("Enable alarm"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(alarm.isEnabled ? Color.accentColor.opacity(0.25) : Color.clear, lineWidth: 1)
        )
        .opacity(alarm.isEnabled ? 1 : 0.7)
        .contextMenu {
            // Preview first local track (disabled when none is playable)
            Button(action: {
                guard let preview = self.firstLocalPreview else { return }
                self.audioManager.togglePreview(url: URL(fileURLWithPath: preview.path), name: preview.name)
            }) {
                Text(L("Preview Sound"))
            }
            .disabled(self.firstLocalPreview == nil)

            Divider()

            Button(action: { self.onEdit(self.alarm) }) {
                Text(L("Edit Alarm"))
            }

            Button(action: { self.store.skipNext(id: self.alarm.id) }) {
                Text(L("Skip next occurrence"))
            }

            Divider()

            Button(action: { self.onDelete(self.alarm) }) {
                Text(L("Delete Alarm"))
            }
        }
    }

    /// The first playable local track (name + path), if any — used for the
    /// "Preview Sound" context-menu entry.
    private var firstLocalPreview: (name: String, path: String)? {
        for case .local(let name, let path, _) in alarm.tracks
        where FileManager.default.fileExists(atPath: path) {
            return (name, path)
        }
        return nil
    }

    private var enabledBinding: Binding<Bool> {
        Binding(
            get: { self.alarm.isEnabled },
            set: { newValue in self.store.toggleEnabled(id: self.alarm.id, enabled: newValue) }
        )
    }

    private func repeatIcon(for type: RepeatType) -> String {
        switch type {
        case .once: return "①"
        case .daily: return "↻"
        case .weekdays: return "⑤"
        case .custom: return "⑦"
        }
    }

    private var isAwaitingWakeConfirmation: Bool {
        alarm.wakeConfirmationState == .pending
            || alarm.wakeConfirmationState == .stoppedWithoutConfirmation
    }

    private var wakeConfirmationLabel: String {
        switch alarm.wakeConfirmationState {
        case .none: return ""
        case .pending: return L("• Wake-up pending")
        case .confirmed: return L("• Wake-up confirmed")
        case .stoppedWithoutConfirmation: return L("• Wake-up not confirmed")
        case .expired: return L("• Wake-up confirmation expired")
        }
    }

    private var wakeConfirmationColor: Color {
        switch alarm.wakeConfirmationState {
        case .confirmed: return .green
        case .pending, .stoppedWithoutConfirmation: return .orange
        case .expired: return .red
        case .none: return .secondary
        }
    }

    private var wakeTimingView: some View {
        VStack(alignment: .leading, spacing: 1) {
            if let started = alarm.wakeStartedAt {
                Text(String(format: L("Started %@"), formatTime(started)))
            }
            if let stopped = alarm.wakeStoppedAt {
                Text(String(format: L("Stopped %@"), formatTime(stopped)))
            }
            if let confirmed = alarm.wakeConfirmedAt {
                Text(String(format: L("Confirmed %@"), formatTime(confirmed)))
            }
            if let deadline = alarm.wakeConfirmationDeadline,
               alarm.wakeConfirmedAt == nil,
               alarm.wakeConfirmationState != .expired {
                Text(String(format: L("Confirm by %@"), formatTime(deadline)))
            }
        }
        .font(.caption2)
        .foregroundColor(.secondary)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }
}
