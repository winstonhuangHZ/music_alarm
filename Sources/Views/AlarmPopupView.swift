import SwiftUI

/// The high-level popup shown while an alarm is ringing, with Snooze / Stop.
struct AlarmPopupView: View {
    let alarm: AlarmItem
    let onSnooze: (AlarmItem) -> Void
    let onStop: (AlarmItem) -> Void

    @State private var appeared = false
    @State private var pulse = false

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
        Text("⏰")
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
    /// (local + Spotify, freely mixable) that the alarm plays sequentially.
    /// Tracks are numbered with their icon and display name; the first track
    /// carries a "now playing" marker because `AlarmEngine` starts there.
    private var trackSection: some View {
        VStack(spacing: 6) {
            if alarm.tracks.isEmpty {
                HStack(spacing: 6) {
                    Text("⚠️")
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
                    Text(alarm.hasSound ? alarm.sourceSummary : "⚠️")
                        .font(.system(size: 11))
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
                                    Text(track.icon)
                                        .font(.system(size: 11))
                                    Text(track.displayName)
                                        .font(.caption)
                                        .foregroundColor(Color.secondary)
                                        .lineLimit(1)
                                    Spacer()
                                    if idx == 0 {
                                        Text("🔊")
                                            .font(.system(size: 10))
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
        HStack(spacing: 18) {
            Button(action: { self.onSnooze(self.alarm) }) {
                HStack(spacing: 8) {
                    Text("💤")
                    Text(L("Snooze 5 min"))
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                .background(Color.orange)
                .cornerRadius(9)
            }
            .buttonStyle(PlainButtonStyle())

            Button(action: { self.onStop(self.alarm) }) {
                HStack(spacing: 8) {
                    Text("⏹")
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
        }
        .opacity(appeared ? 1 : 0)
        .scaleEffect(appeared ? 1 : 0.9)
    }
}