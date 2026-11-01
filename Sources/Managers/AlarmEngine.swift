import Foundation
import Combine
import AppKit

/// Background alarm engine. Tracks concrete scheduled occurrences instead of
/// requiring a timer tick to land in one exact minute.
final class AlarmEngine: ObservableObject {
    @Published private(set) var isRinging = false
    @Published private(set) var ringingAlarm: AlarmItem?

    private var deadlineTimer: Timer?
    private let store: AlarmStore
    private let audioManager: AudioManager

    private struct FireCandidate {
        let alarm: AlarmItem
        let occurrence: Date
        let isSnooze: Bool
        let isTest: Bool
    }

    /// Index of the currently playing track (for sequential playlist support).
    private var currentTrackIndex: Int = 0
    private var currentCandidate: FireCandidate?
    private var pendingCandidates: [FireCandidate] = []
    private var claimedAlarmIDs = Set<UUID>()
    private var maximumDurationTimer: Timer?
    private var wakeObserver: NSObjectProtocol?
    private var activeObserver: NSObjectProtocol?
    private var clockObserver: NSObjectProtocol?
    private var storeCancellable: AnyCancellable?

    private enum TickReason { case regular, wake }

    init(store: AlarmStore, audioManager: AudioManager) {
        self.store = store
        self.audioManager = audioManager
    }

    func start() {
        guard deadlineTimer == nil else { return }
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
        clockObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("NSSystemClockDidChangeNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in self?.tick(reason: .regular) }
        storeCancellable = store.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async { self?.scheduleNextDeadline() }
        }
        tick(reason: .regular)
    }

    func stop() {
        deadlineTimer?.invalidate()
        deadlineTimer = nil
        if let wakeObserver { NotificationCenter.default.removeObserver(wakeObserver) }
        if let activeObserver { NotificationCenter.default.removeObserver(activeObserver) }
        if let clockObserver { NotificationCenter.default.removeObserver(clockObserver) }
        wakeObserver = nil
        activeObserver = nil
        clockObserver = nil
        storeCancellable = nil
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
        scheduleNextDeadline()
    }

    private func scheduleNextDeadline() {
        deadlineTimer?.invalidate()
        deadlineTimer = nil
        guard let date = store.nextAlarmFire(at: Date()).date else { return }
        let interval = max(0.1, date.timeIntervalSinceNow)
        deadlineTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            self?.deadlineTimer = nil
            self?.tick(reason: .regular)
        }
    }

    private func dueCandidate(for alarm: AlarmItem, now: Date, reason: TickReason) -> FireCandidate? {
        if let snooze = alarm.snoozeUntil, snooze <= now {
            return FireCandidate(alarm: alarm, occurrence: snooze, isSnooze: true, isTest: false)
        }
        guard let occurrence = alarm.mostRecentOccurrence(at: now),
              shouldCatchUp(occurrence: occurrence, now: now, reason: reason),
              alarm.lastFiredKey != AlarmTimeUtil.fireKey(for: occurrence) else { return nil }
        return FireCandidate(alarm: alarm, occurrence: occurrence, isSnooze: false, isTest: false)
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
        maximumDurationTimer?.invalidate()
        if alarm.maximumPlaybackMinutes > 0 {
            maximumDurationTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(alarm.maximumPlaybackMinutes * 60),
                                                        repeats: false) { [weak self] _ in
                self?.stopRinging()
            }
        }
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
                                     numberOfLoops: 0,
                                     fadeDuration: TimeInterval(alarm.fadeDurationSeconds),
                                     targetVolume: Float(alarm.targetVolumePercent) / 100) {
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
              !candidate.isTest,
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
        if let alarm = ringingAlarm, currentTrackIndex >= alarm.tracks.count {
            if alarm.loopsPlaylist {
                currentTrackIndex = 0
            } else {
                audioManager.stop()
                return
            }
        }
        playCurrentTrack()
    }

    /// Starts a non-persistent test session using the first enabled alarm with
    /// a playable track, or the system fallback when none is available.
    func testAlarm() {
        guard currentCandidate == nil else { return }
        let alarm = store.alarms.first(where: { $0.isEnabled && $0.hasSound })
            ?? store.alarms.first
            ?? AlarmItem()
        currentCandidate = FireCandidate(alarm: alarm,
                                          occurrence: Date(),
                                          isSnooze: true,
                                          isTest: true)
        trigger(candidate: currentCandidate!)
    }

    // MARK: - User actions

    func stopRinging() {
        if let alarm = ringingAlarm, currentCandidate?.isTest != true {
            store.stopAlarm(alarm)
        }
        audioManager.stop()
        finishCurrent()
    }

    func snoozeRinging(minutes: Int = 5) {
        guard let alarm = ringingAlarm else { return }
        if currentCandidate?.isTest != true {
            store.snooze(alarm, minutes: alarm.snoozeMinutes)
        }
        audioManager.stop()
        finishCurrent()
    }

    func confirmWake() {
        guard let alarm = ringingAlarm else { return }
        if currentCandidate?.isTest != true {
            store.confirmWake(id: alarm.id)
        }
        audioManager.stop()
        finishCurrent()
    }

    private func finishCurrent() {
        maximumDurationTimer?.invalidate()
        maximumDurationTimer = nil
        isRinging = false
        ringingAlarm = nil
        if let candidate = currentCandidate {
            claimedAlarmIDs.remove(candidate.alarm.id)
        }
        currentCandidate = nil
        AlarmPopupController.dismiss()
        startNextIfNeeded()
        scheduleNextDeadline()
    }
}
