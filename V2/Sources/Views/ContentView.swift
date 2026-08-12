import SwiftUI
import AppKit

/// Main window layout:
///   Top    – large digital clock + prominent "next alarm" countdown
///   Middle – alarm list cards
///   Bottom – music library bar + Add Alarm button
struct ContentView: View {
    @EnvironmentObject var store: AlarmStore
    @EnvironmentObject var audioManager: AudioManager
    @EnvironmentObject var languageManager: LanguageManager

    @State private var showAddAlarm = false
    @State private var editingAlarm: AlarmItem?
    @State private var now = Date()
    @State private var clockTimer: Timer?

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            alarmListView
            Divider()
            AudioBarView()
            Divider()
            footerBar
        }
        .frame(minWidth: 760, minHeight: 640)
        .background(Color(NSColor.windowBackgroundColor))
        .sheet(isPresented: $showAddAlarm) {
            AddAlarmView(alarm: self.editingAlarm)
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

    // MARK: - Header

    private var headerView: some View {
        VStack(spacing: 10) {
            DigitalClockView()
            countdownView
        }
        .padding(.top, 34) // clear the traffic-light buttons
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity)
        .background(VisualEffectView())
    }

    private var countdownView: some View {
        let next = store.nextAlarmFire(at: now)
        let hasNext = next.date != nil
        let countdownText: String
        if let date = next.date {
            countdownText = countdownString(from: now, to: date)
        } else {
            countdownText = ""
        }
        let detailText = next.alarm.map {
            "\($0.timeString)  •  \($0.repeatText)  •  \($0.audioDisplayName)"
        } ?? ""
        let hasDetail = !detailText.isEmpty

        return VStack(spacing: 4) {
            HStack(spacing: 6) {
                Text("⏳")
                if hasNext {
                    Text(String(format: L("Next alarm in %@"), countdownText))
                } else {
                    Text(L("No upcoming alarm"))
                }
            }
            .font(.system(size: 17, weight: .semibold))
            .foregroundColor(Color.secondary)

            if hasDetail {
                HStack(spacing: 6) {
                    Text("🎵")
                    Text(detailText)
                }
                .font(.caption)
                .foregroundColor(Color.secondary)
                .lineLimit(1)
            }
        }
    }

    private func countdownString(from now: Date, to target: Date) -> String {
        let secs = Int(target.timeIntervalSince(now))
        if secs < 0 { return L("now") }
        let h = secs / 3600
        let m = (secs % 3600) / 60
        let s = secs % 60
        if h > 0 { return String(format: L("%dh %dm"), h, m) }
        if m > 0 { return String(format: L("%dm %ds"), m, s) }
        return String(format: L("%ds"), s)
    }

    // MARK: - Alarm list

    private var alarmListView: some View {
        Group {
            if store.alarms.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(store.alarms) { alarm in
                            AlarmRowView(
                                alarm: alarm,
                                onEdit: { target in
                                    self.beginEditing(target)
                                },
                                onDelete: { target in
                                    self.store.removeAlarm(target)
                                }
                            )
                        }
                    }
                    .padding(14)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Text("⏰")
                .font(.system(size: 44))
                .foregroundColor(Color.secondary)
            Text(L("No alarms yet"))
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(Color.secondary)
            Text(L("Click “Add Alarm” to create your first alarm."))
                .font(.caption)
                .foregroundColor(Color.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Add / Edit

    /// Opens the add-alarm sheet in "new alarm" mode.
    private func showNewAlarm() {
        editingAlarm = nil
        showAddAlarm = true
    }

    /// Opens the add-alarm sheet pre-filled with an existing alarm.
    private func beginEditing(_ alarm: AlarmItem) {
        editingAlarm = alarm
        showAddAlarm = true
    }

    // MARK: - Footer

    private var footerBar: some View {
        HStack {
            languagePicker
            Spacer()
            Button(action: { self.showNewAlarm() }) {
                HStack(spacing: 8) {
                    Text("➕")
                    Text(L("Add Alarm"))
                }
                .font(.headline)
                .foregroundColor(Color.red)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
            }
            .buttonStyle(BorderedButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    /// In-app language switcher picker (bottom-left of the footer).
    private var languagePicker: some View {
        HStack(spacing: 8) {
            Text("🌐")
                .font(.system(size: 14))
                .foregroundColor(Color.secondary)
            Picker(selection: $languageManager.selectedLanguage, label: EmptyView()) {
                Text(L("System Default")).tag("")
                Text("English").tag("en")
                Text("简体中文").tag("zh-Hans")
                Text("繁體中文").tag("zh-Hant")
                Text("Français").tag("fr")
                Text("Español").tag("es")
                Text("Русский").tag("ru")
                Text("العربية").tag("ar")
            }
            .frame(width: 170)
        }
    }
}
