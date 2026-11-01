import Foundation
import Combine
import AppKit

/// Background alarm engine. Tracks concrete scheduled occurrences instead of
/// requiring a timer tick to land in one exact minute.
final class AlarmEngine: ObservableObject {
    @Published private(set) var isRinging = false
    @Published private(set) var ringingAlarm: AlarmItem?

    private var timer: Timer?
    private let store: AlarmStore
    private let audioManager: AudioManager

    private struct FireCandidate {
        let alarm: AlarmItem
        let occurrence: Date
        let isSnooze: Bool
    }

    /// Index of the currently playing track (for sequential playlist support).
    private var currentTrackIndex: Int = 0
    private var currentCandidate: FireCandidate?
    private var pendingCandidates: [FireCandidate] = []
    private var claimedAlarmIDs = Set<UUID>()
    private var wakeObserver: NSObjectProtocol?
    private var activeObserver: NSObjectProtocol?

    private enum TickReason { case regular, wake }

    init(store: AlarmStore, audioManager: AudioManager) {
        self.store = store
        self.audioManager = audioManager
    }

    func start() {
        guard timer == nil else { return }
        let t = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick(reason: .regular)
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
        wakeObserver = NotificationCenter.default.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in self?.tick(reason: .wake) }
        activeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in self?.tick(reason: .regular) }
        tick(reason: .regular)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        if let wakeObserver { NotificationCenter.default.removeObserver(wakeObserver) }
        if let activeObserver { NotificationCenter.default.removeObserver(activeObserver) }
        wakeObserver = nil
        activeObserver = nil
    }

    private func tick(reason: TickReason = .regular) {
        let now = Date()
        for alarm in store.alarms where alarm.isEnabled {
            guard !claimedAlarmIDs.contains(alarm.id),
                  let candidate = dueCandidate(for: alarm, now: now, reason: reason) else { continue }
            claimedAlarmIDs.insert(alarm.id)
            pendingCandidates.append(candidate)
        }
        startNextIfNeeded()
    }

    private func dueCandidate(for alarm: AlarmItem, now: Date, reason: TickReason) -> FireCandidate? {
        if let snooze = alarm.snoozeUntil, snooze <= now {
            return FireCandidate(alarm: alarm, occurrence: snooze, isSnooze: true)
        }
        guard let occurrence = alarm.mostRecentOccurrence(at: now),
              shouldCatchUp(occurrence: occurrence, now: now, reason: reason),
              alarm.lastFiredKey != AlarmTimeUtil.fireKey(for: occurrence) else { return nil }
        return FireCandidate(alarm: alarm, occurrence: occurrence, isSnooze: false)
    }

    private func shouldCatchUp(occurrence: Date, now: Date, reason: TickReason) -> Bool {
        let age = now.timeIntervalSince(occurrence)
        guard age >= 0 else { return false }
        if age <= 2 { return true }
        let policy = AppSettings.shared.missedAlarmPolicy
        if policy == .wakeOnly && reason != .wake { return false }
        guard let window = policy.catchUpWindow else { return false }
        return age <= window
    }

    private func startNextIfNeeded() {
        guard currentCandidate == nil else { return }
        while !pendingCandidates.isEmpty {
            let candidate = pendingCandidates.removeFirst()
            guard let liveAlarm = store.alarms.first(where: { $0.id == candidate.alarm.id }),
                  liveAlarm.isEnabled else {
                claimedAlarmIDs.remove(candidate.alarm.id)
                continue
            }
            currentCandidate = candidate
            trigger(candidate: candidate)
            return
        }
    }

    // MARK: - Playlist playback

    private func trigger(candidate: FireCandidate) {
        let alarm = candidate.alarm
        isRinging = true
        ringingAlarm = alarm
        currentTrackIndex = 0
        playCurrentTrack()
        AlarmPopupController.show(
            alarm: alarm,
            onSnooze: { [weak self] _ in self?.snoozeRinging() },
            onStop: { [weak self] _ in self?.stopRinging() },
            onConfirmWake: { [weak self] _ in self?.confirmWake() }
        )
    }

    /// Plays the current track. Failed tracks are skipped before falling back
    /// to the system sound.
    private func playCurrentTrack() {
        guard let alarm = ringingAlarm else { return }
        let tracks = alarm.tracks

        while currentTrackIndex < tracks.count {
            let track = tracks[currentTrackIndex]
            switch track {
            case .local(_, let path, _):
                if FileManager.default.fileExists(atPath: path),
                   audioManager.ring(url: URL(fileURLWithPath: path),
                                     name: track.displayName,
                                     numberOfLoops: 0) {
                    markPlaybackStartedIfNeeded()
                    return
                }
            case .unavailable:
                break
            }
            currentTrackIndex += 1
        }

        if audioManager.ringFallback() {
            markPlaybackStartedIfNeeded()
        }
    }

    private func markPlaybackStartedIfNeeded() {
        guard let candidate = currentCandidate,
              let liveAlarm = store.alarms.first(where: { $0.id == candidate.alarm.id }) else { return }
        if candidate.isSnooze || liveAlarm.lastFiredKey != AlarmTimeUtil.fireKey(for: candidate.occurrence) {
            store.markPlaybackStarted(id: candidate.alarm.id,
                                      occurrence: candidate.occurrence,
                                      isSnooze: candidate.isSnooze)
        }
    }

    /// Called by AudioManager when a local track finishes playing. Advances to
    /// the next track and loops the playlist after its last track.
    func advanceToNextTrack() {
        guard ringingAlarm != nil else { return }
        currentTrackIndex += 1
        playCurrentTrack()
    }

    // MARK: - User actions

    func stopRinging() {
        if let alarm = ringingAlarm { store.stopAlarm(alarm) }
        audioManager.stop()
        finishCurrent()
    }

    func snoozeRinging(minutes: Int = 5) {
        guard let alarm = ringingAlarm else { return }
        store.snooze(alarm, minutes: minutes)
        audioManager.stop()
        finishCurrent()
    }

    func confirmWake() {
        guard let alarm = ringingAlarm else { return }
        store.confirmWake(id: alarm.id)
        audioManager.stop()
        finishCurrent()
    }

    private func finishCurrent() {
        isRinging = false
        ringingAlarm = nil
        if let candidate = currentCandidate {
            claimedAlarmIDs.remove(candidate.alarm.id)
        }
        currentCandidate = nil
        AlarmPopupController.dismiss()
        startNextIfNeeded()
    }
}
