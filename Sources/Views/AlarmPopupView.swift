import SwiftUI
import AppKit

/// The high-level popup shown while an alarm is ringing, with Snooze / Stop.
struct AlarmPopupView: View {
    let alarm: AlarmItem
    let onSnooze: (AlarmItem) -> Void
    let onStop: (AlarmItem) -> Void
    let onConfirmWake: (AlarmItem) -> Void
    @ObservedObject private var settings = AppSettings.shared

    @State private var appeared = false
    @State private var pulse = false
    @State private var confirmationInput = ""
    @State private var slideProgress = 0.0
    @State private var gestureCompleted = false

    var body: some View {
        popupCard
            .onAppear {
                withAnimation(Animation.easeOut(duration: 0.4)) {
                    self.appeared = true
                }
            }
    }

    private var popupCard: some View {
        VStack(spacing: 14) {
            alarmIcon
            titleText
            timeText
            trackSection
            actionButtons
        }
        .padding(32)
        .frame(width: 460)
        .opacity(appeared ? 1 : 0)
        .scaleEffect(appeared ? 1 : 0.6)
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.3), radius: 30, y: 10)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var alarmIcon: some View {
        Image(systemName: "alarm.fill")
            .font(.system(size: 46))
            .foregroundColor(.red)
            .scaleEffect(pulse ? 1.2 : 0.92)
            .animation(Animation.easeInOut(duration: 0.7).repeatForever(autoreverses: true))
            .onAppear { self.pulse = true }
    }

    private var titleText: some View {
        Text(L("Time to wake up!"))
            .font(.system(size: 28, weight: .bold))
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 8)
    }

    private var timeText: some View {
        Text(alarm.timeString)
            .font(.system(size: 20, weight: .semibold, design: .rounded))
            .foregroundColor(Color.secondary)
            .opacity(appeared ? 1 : 0)
    }

    /// The playlist section: a source summary and the ordered list of tracks
    /// local that the alarm plays sequentially.
    /// Tracks are numbered with their icon and display name; the first track
    /// carries a "now playing" marker because `AlarmEngine` starts there.
    private var trackSection: some View {
        VStack(spacing: 6) {
            if alarm.tracks.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(alarm.audioDisplayName)
                }
                .font(.caption)
                .foregroundColor(Color.secondary)
            } else {
                HStack(spacing: 6) {
                    Text(L("Tracks"))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(Color.secondary)
                    Image(systemName: alarm.hasSound ? "music.note.list" : "exclamationmark.triangle.fill")
                        .font(.system(size: 11, weight: .medium))
                    Text(alarm.audioDisplayName)
                        .font(.caption)
                        .foregroundColor(Color.secondary)
                        .lineLimit(1)
                }

                if alarm.tracks.count > 1 {
                    ScrollView {
                        VStack(spacing: 4) {
                            ForEach(Array(alarm.tracks.enumerated()), id: \.offset) { idx, track in
                                HStack(spacing: 6) {
                                    Text("\(idx + 1)")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(Color.secondary)
                                        .frame(width: 14)
                                    Image(systemName: track.icon)
                                        .font(.system(size: 11, weight: .medium))
                                    Text(track.displayName)
                                        .font(.caption)
                                        .foregroundColor(Color.secondary)
                                        .lineLimit(1)
                                    Spacer()
                                    if idx == 0 {
                                        Image(systemName: "speaker.wave.2.fill")
                                            .font(.system(size: 10, weight: .medium))
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .frame(maxHeight: 96)
                }
            }
        }
        .opacity(appeared ? 1 : 0)
    }

    private var actionButtons: some View {
        VStack(spacing: 10) {
            if alarm.requiresWakeConfirmation && settings.wakeConfirmationEnabled {
                confirmationControl
            }

            HStack(spacing: 18) {
            Button(action: { self.onSnooze(self.alarm) }) {
                HStack(spacing: 8) {
                    Image(systemName: "moon.zzz.fill")
                    Text(String(format: L("Snooze %d min"), alarm.snoozeMinutes))
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                .background(Color.orange)
                .cornerRadius(9)
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel(String(format: L("Snooze %d min"), alarm.snoozeMinutes))

            Button(action: { self.onStop(self.alarm) }) {
                HStack(spacing: 8) {
                    Image(systemName: "stop.fill")
                    Text(L("Stop"))
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                .background(Color.red)
                .cornerRadius(9)
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel(L("Stop"))
            }
        }
        .opacity(appeared ? 1 : 0)
        .scaleEffect(appeared ? 1 : 0.9)
    }

    @ViewBuilder
    private var confirmationControl: some View {
        switch settings.wakeConfirmationMode {
        case .button:
            confirmationButton
        case .shortWord:
            VStack(spacing: 6) {
                TextField(L("Type AWAKE to confirm"), text: $confirmationInput)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .accessibilityLabel(L("Confirmation word"))
                confirmationButton
                    .disabled(confirmationInput.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() != "awake")
            }
        case .hold:
            holdConfirmationControl
        case .slide:
            VStack(spacing: 5) {
                Text(L("Slide to confirm"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                Slider(value: $slideProgress, in: 0...1, onEditingChanged: { editing in
                    if !editing && slideProgress >= 0.99 && !gestureCompleted {
                        gestureCompleted = true
                        onConfirmWake(alarm)
                    }
                })
                .accessibilityLabel(L("Slide to confirm"))
            }
        case .mainWindow:
            Button(action: {
                AlarmPopupController.dismiss()
                NSApp.windows.first(where: { $0.title == "Music Alarm" })?.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "macwindow")
                    Text(L("Confirm from the main window"))
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(Color.green)
                .cornerRadius(9)
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel(L("Confirm from the main window"))
        }
    }

    /// A direct gesture surface is used instead of putting the long-press
    /// gesture on Button. On macOS, Button's click recognizer can consume the
    /// gesture before LongPressGesture reaches its minimum duration.
    private var holdConfirmationControl: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
            Text(L("Hold for 3 seconds"))
        }
        .font(.headline)
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .background(Color.green)
        .cornerRadius(9)
        .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .gesture(
            LongPressGesture(minimumDuration: 3, maximumDistance: 30)
                .onEnded { _ in
                    guard !gestureCompleted else { return }
                    gestureCompleted = true
                    onConfirmWake(alarm)
                }
        )
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(L("Hold for 3 seconds"))
        .accessibilityAction {
            guard !gestureCompleted else { return }
            gestureCompleted = true
            onConfirmWake(alarm)
        }
    }

    private var confirmationButton: some View {
        Button(action: { self.onConfirmWake(self.alarm) }) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                Text(L("I am really awake"))
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(Color.green)
            .cornerRadius(9)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel(L("I am really awake"))
    }
}
