import SwiftUI

/// One alarm card in the list: time, repeat info, sound name, enable toggle,
/// and a context menu with preview / delete.
struct AlarmRowView: View {
    @EnvironmentObject var store: AlarmStore
    @EnvironmentObject var audioManager: AudioManager
    @EnvironmentObject var languageManager: LanguageManager

    let alarm: AlarmItem
    let onEdit: (AlarmItem) -> Void
    let onDelete: (AlarmItem) -> Void

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
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
                }
                .foregroundColor(.secondary)
            }

            Spacer()

            HStack(spacing: 6) {
                Text(alarm.soundSource == .spotify ? "🎧" : (alarm.hasAudio ? "♪" : "⚠️"))
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

            Toggle(isOn: enabledBinding) {
                Text("")
            }
            .labelsHidden()
            .toggleStyle(SwitchToggleStyle())
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
            if self.alarm.soundSource == .local {
                Button(action: {
                    if let path = self.alarm.audioPath, FileManager.default.fileExists(atPath: path) {
                        self.audioManager.togglePreview(url: URL(fileURLWithPath: path), name: (self.alarm.audioName ?? ""))
                    }
                }) {
                    Text(L("Preview Sound"))
                }
                .disabled(!self.alarm.hasAudio)

                Divider()
            }

            Button(action: { self.onEdit(self.alarm) }) {
                Text(L("Edit Alarm"))
            }

            Divider()

            Button(action: { self.onDelete(self.alarm) }) {
                Text(L("Delete Alarm"))
            }
        }
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
        }
    }
}
