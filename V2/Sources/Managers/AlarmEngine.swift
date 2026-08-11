import Foundation
import Combine

/// Background alarm engine. Checks the clock every second and fires matching
/// alarms by starting audio playback and showing the high-level popup panel.
final class AlarmEngine: ObservableObject {
    @Published private(set) var isRinging = false
    @Published private(set) var ringingAlarm: AlarmItem?

    private var timer: Timer?
    private let store: AlarmStore
    private let audioManager: AudioManager
    private let spotifyBridge: SpotifyBridge

    init(store: AlarmStore, audioManager: AudioManager, spotifyBridge: SpotifyBridge = .shared) {
        self.store = store
        self.audioManager = audioManager
        self.spotifyBridge = spotifyBridge
    }

    func start() {
        guard timer == nil else { return }
        let t = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
        tick()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// Evaluate all enabled alarms against the current time.
    func tick() {
        guard !isRinging else { return } // only one alarm rings at a time
        let now = Date()
        for index in store.alarms.indices {
            guard store.alarms[index].isEnabled else { continue }
            if shouldFire(store.alarms[index], now: now) {
                store.markFired(at: index, now: now)
                let alarm = store.alarms[index]
                trigger(alarm: alarm)
                break
            }
        }
    }

    private func shouldFire(_ alarm: AlarmItem, now: Date) -> Bool {
        let cal = Calendar.current

        // Snoozed alarm: fire once the snooze time has been reached.
        if let snooze = alarm.snoozeUntil {
            return now >= snooze
        }

        let comps = cal.dateComponents([.hour, .minute, .weekday], from: now)
        guard comps.hour == alarm.hour, comps.minute == alarm.minute else { return false }

        switch alarm.repeatType {
        case .once, .daily:
            break
        case .weekdays:
            guard let wd = comps.weekday, (2...6).contains(wd) else { return false }
        }

        // Avoid firing repeatedly within the same minute.
        return alarm.lastFiredKey != AlarmTimeUtil.fireKey(for: now)
    }

    private func trigger(alarm: AlarmItem) {
        isRinging = true
        ringingAlarm = alarm

        switch alarm.soundSource {
        case .spotify:
            // Try to start the Spotify playlist; fall back to the built-in
            // sound if Spotify is missing, not running, or the script fails.
            if !spotifyBridge.playPlaylist(from: alarm.spotifyPlaylistURL ?? "") {
                audioManager.ringFallback()
            }
        case .local:
            if let path = alarm.audioPath, FileManager.default.fileExists(atPath: path) {
                audioManager.ring(url: URL(fileURLWithPath: path), name: alarm.audioName)
            } else {
                audioManager.ringFallback()
            }
        }

        AlarmPopupController.show(
            alarm: alarm,
            onSnooze: { [weak self] _ in self?.snoozeRinging() },
            onStop: { [weak self] _ in self?.stopRinging() }
        )
    }

    func stopRinging() {
        guard let alarm = ringingAlarm else {
            audioManager.stop()
            isRinging = false
            AlarmPopupController.dismiss()
            return
        }
        store.stopAlarm(alarm)
        audioManager.stop()
        spotifyBridge.pause()
        isRinging = false
        ringingAlarm = nil
        AlarmPopupController.dismiss()
    }

    func snoozeRinging(minutes: Int = 5) {
        guard let alarm = ringingAlarm else { return }
        store.snooze(alarm, minutes: minutes)
        audioManager.stop()
        spotifyBridge.pause()
        isRinging = false
        ringingAlarm = nil
        AlarmPopupController.dismiss()
    }
}
