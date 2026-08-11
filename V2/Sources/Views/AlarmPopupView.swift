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
            soundText
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
        Text("Time to wake up!")
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

    private var soundText: some View {
        Text("\(alarm.soundSource == .spotify ? "🎧" : "🎵") \(alarm.audioDisplayName)")
            .font(.caption)
            .foregroundColor(Color.secondary)
            .opacity(appeared ? 1 : 0)
    }

    private var actionButtons: some View {
        HStack(spacing: 18) {
            Button(action: { self.onSnooze(self.alarm) }) {
                HStack(spacing: 8) {
                    Text("💤")
                    Text("Snooze 5 min")
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
                    Text("Stop")
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
