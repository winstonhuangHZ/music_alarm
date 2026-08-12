import Foundation
import Combine

/// Background alarm engine. Checks the clock every second and fires matching
/// alarms by playing each track in the alarm's playlist sequentially, starting
/// with the first local track or Spotify link.
final class AlarmEngine: ObservableObject {
    @Published private(set) var isRinging = false
    @Published private(set) var ringingAlarm: AlarmItem?

    private var timer: Timer?
    private let store: AlarmStore
    private let audioManager: AudioManager
    private let spotifyBridge: SpotifyBridge

    /// Index of the currently playing track (for sequential playback).
    private var currentTrackIndex: Int = 0

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

    func tick() {
        guard !isRinging else { return }
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
        if let snooze = alarm.snoozeUntil { return now >= snooze }
        let comps = cal.dateComponents([.hour, .minute, .weekday], from: now)
        guard comps.hour == alarm.hour, comps.minute == alarm.minute else { return false }
        switch alarm.repeatType {
        case .once, .daily: break
        case .weekdays:
            guard let wd = comps.weekday, (2...6).contains(wd) else { return false }
        }
        return alarm.lastFiredKey != AlarmTimeUtil.fireKey(for: now)
    }

    // MARK: - Playlist playback

    private func trigger(alarm: AlarmItem) {
        isRinging = true
        ringingAlarm = alarm
        currentTrackIndex = 0
        playCurrentTrack()
        AlarmPopupController.show(
            alarm: alarm,
            onSnooze: { [weak self] _ in self?.snoozeRinging() },
            onStop: { [weak self] _ in self?.stopRinging() }
        )
    }

    /// Plays the track at `currentTrackIndex`. Falls back to a beep when no
    /// track is playable.
    private func playCurrentTrack() {
        guard let alarm = ringingAlarm else { return }
        let tracks = alarm.tracks

        // Advance past any unplayable or already-exhausted local tracks.
        while currentTrackIndex < tracks.count {
            let track = tracks[currentTrackIndex]
            switch track {
            case .local(_, let path, _):
                if FileManager.default.fileExists(atPath: path) {
                    audioManager.ring(url: URL(fileURLWithPath: path), name: track.displayName,
                                      numberOfLoops: 0)
                    return
                }
            case .spotify(let link):
                if SpotifySupport.spotifyType(from: link).isValid {
                    if spotifyBridge.playSpotify(from: link) {
                        return
                    }
                }
            }
            currentTrackIndex += 1
        }

        // No track could be played — fall back to system beep.
        audioManager.ringFallback()
    }

    /// Called by AudioManager when a local track finishes playing (for
    /// sequential playlist support). Advances to the next track in the list.
    func advanceToNextTrack() {
        guard let alarm = ringingAlarm else { return }
        currentTrackIndex += 1
        if currentTrackIndex < alarm.tracks.count {
            playCurrentTrack()
        } else {
            // All tracks exhausted — loop back to the first.
            currentTrackIndex = 0
            playCurrentTrack()
        }
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