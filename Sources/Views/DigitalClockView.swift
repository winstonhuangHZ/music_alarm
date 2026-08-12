import SwiftUI

/// Large modern digital clock with the current date.
struct DigitalClockView: View {
    @State private var now = Date()
    @State private var clockTimer: Timer?

    var body: some View {
        VStack(spacing: 3) {
            Text(timeText(now))
                .font(.system(size: 62, weight: .thin, design: .rounded))
                .foregroundColor(Color.primary)
            Text(dateText(now))
                .font(.subheadline)
                .foregroundColor(Color.secondary)
        }
        .onAppear {
            self.startClock()
        }
        .onDisappear {
            self.clockTimer?.invalidate()
            self.clockTimer = nil
        }
    }

    private func startClock() {
        clockTimer?.invalidate()
        let t = Timer(timeInterval: 1.0, repeats: true) { _ in
            self.now = Date()
        }
        RunLoop.main.add(t, forMode: .common)
        clockTimer = t
        now = Date()
    }

    private func timeText(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f.string(from: date)
    }

    private func dateText(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale.current
        f.setLocalizedDateFormatFromTemplate("EEEEdMMMMy")
        return f.string(from: date)
    }
}
