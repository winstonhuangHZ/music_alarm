import Foundation
import Combine
import AppKit

/// Background alarm engine. Tracks concrete scheduled occurrences instead of
/// requiring a timer tick to land in one exact minute.
final class AlarmEngine: ObservableObject {
    @Published private(set) var isRinging = false
    @Published private(set) var ringingAlarm: AlarmItem?
    @Published private(set) var lastDiagnostic: String = ""

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
    private var playedTrackIndices = Set<Int>()
    private var currentCandidate: FireCandidate?
    private var currentOccurrenceID: UUID?
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
        lastDiagnostic = String(format: L("Scheduler checked at %@"), diagnosticDate(now))
        store.reconcileWakeConfirmationStates(now: now)
        for alarm in store.alarms where store.isAlarmEnabled(alarm, now: now) {
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
                  store.isAlarmEnabled(liveAlarm) else {
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
        playedTrackIndices = []
        currentOccurrenceID = nil
        guard playCurrentTrack() else {
            finishCurrent()
            return
        }
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
        if !candidate.isTest {
            AlarmNotificationManager.shared.notify(alarm: alarm)
        }
    }

    /// Plays the current track. Failed tracks are skipped before falling back
    /// to the system sound.
    @discardableResult
    private func playCurrentTrack() -> Bool {
        guard let alarm = ringingAlarm else { return false }
        let tracks = alarm.tracks
        var attemptedTracks: [String] = []
        var failures: [String] = []

        while currentTrackIndex < tracks.count {
            let track = tracks[currentTrackIndex]
            let trackSettings = alarm.trackPlaybackSettings.indices.contains(currentTrackIndex)
                ? alarm.trackPlaybackSettings[currentTrackIndex]
                : TrackPlaybackSettings(volumePercent: alarm.targetVolumePercent,
                                        fadeDurationSeconds: alarm.fadeDurationSeconds)
            let volumePercent = alarm.stagedWakeEnabled
                ? trackSettings.clampedVolumePercent
                : alarm.targetVolumePercent
            let fadeDuration = alarm.stagedWakeEnabled
                ? trackSettings.clampedFadeDurationSeconds
                : alarm.fadeDurationSeconds
            switch track {
            case .local(_, let path, _):
                attemptedTracks.append(track.displayName)
                if FileManager.default.fileExists(atPath: path),
                   audioManager.ring(url: URL(fileURLWithPath: path),
                                     name: track.displayName,
                                     numberOfLoops: alarm.playlistPlaybackMode == .repeatOne && alarm.loopsPlaylist ? -1 : 0,
                                     fadeDuration: TimeInterval(fadeDuration),
                                     targetVolume: Float(volumePercent) / 100) {
                    markPlaybackStartedIfNeeded(usedFallback: false,
                                                attemptedTracks: attemptedTracks)
                    return true
                } else if !FileManager.default.fileExists(atPath: path) {
                    failures.append(String(format: L("File missing: %@"), track.displayName))
                } else if let error = audioManager.lastPlaybackError {
                    failures.append(String(format: L("Audio failed: %@"), error))
                }
            case .unavailable:
                break
            }
            currentTrackIndex += 1
        }

        if audioManager.ringFallback(name: AppSettings.shared.fallbackSoundChoice.rawValue) {
            lastDiagnostic = L("Playback started with system fallback")
            markPlaybackStartedIfNeeded(usedFallback: true,
                                        attemptedTracks: attemptedTracks)
            return true
        }
        if let candidate = currentCandidate, !candidate.isTest, currentOccurrenceID == nil {
            lastDiagnostic = String(format: L("Playback failed for %@"), candidate.alarm.label.isEmpty ? candidate.alarm.timeString : candidate.alarm.label)
            store.markPlaybackFailed(id: candidate.alarm.id,
                                     occurrence: candidate.occurrence,
                                     isSnooze: candidate.isSnooze,
                                     reason: (failures + [audioManager.lastPlaybackError].compactMap { $0 }).joined(separator: "; ").isEmpty
                                        ? (attemptedTracks.isEmpty ? L("No playable audio or system fallback") : L("All configured audio tracks failed"))
                                        : (failures + [audioManager.lastPlaybackError].compactMap { $0 }).joined(separator: "; "),
                                     attemptedTracks: attemptedTracks)
        }
        return false
    }

    private func markPlaybackStartedIfNeeded(usedFallback: Bool,
                                             attemptedTracks: [String]) {
        guard let candidate = currentCandidate,
              !candidate.isTest,
              let liveAlarm = store.alarms.first(where: { $0.id == candidate.alarm.id }) else { return }
        if candidate.isSnooze || liveAlarm.lastFiredKey != AlarmTimeUtil.fireKey(for: candidate.occurrence) {
            currentOccurrenceID = store.markPlaybackStarted(id: candidate.alarm.id,
                                                             occurrence: candidate.occurrence,
                                                             isSnooze: candidate.isSnooze,
                                                             usedFallback: usedFallback,
                                                             attemptedTracks: attemptedTracks)
        }
    }

    /// Called by AudioManager when a local track finishes playing. Advances to
    /// the next track and loops the playlist after its last track.
    func advanceToNextTrack() {
        guard let alarm = ringingAlarm, currentCandidate != nil else { return }

        if alarm.playlistPlaybackMode == .repeatOne {
            guard alarm.loopsPlaylist else {
                stopRinging()
                return
            }
            _ = playCurrentTrack()
            return
        }

        let nextIndex: Int
        if alarm.playlistPlaybackMode == .shuffle, alarm.tracks.count > 1 {
            playedTrackIndices.insert(currentTrackIndex)
            let remaining = alarm.tracks.indices.filter { !playedTrackIndices.contains($0) }
            if let shuffledNext = remaining.randomElement() {
                nextIndex = shuffledNext
            } else if alarm.loopsPlaylist {
                playedTrackIndices = []
                nextIndex = alarm.tracks.indices.filter { $0 != currentTrackIndex }.randomElement() ?? currentTrackIndex
            } else {
                stopRinging()
                return
            }
        } else {
            nextIndex = currentTrackIndex + 1
        }
        if nextIndex >= alarm.tracks.count {
            guard alarm.loopsPlaylist else {
                stopRinging()
                return
            }
            currentTrackIndex = 0
        } else {
            currentTrackIndex = nextIndex
        }

        if !playCurrentTrack() {
            finishCurrent()
        }
    }

    /// Starts a non-persistent test session using the first enabled alarm with
    /// a playable track, or the system fallback when none is available.
    func testAlarm() {
        guard currentCandidate == nil else { return }
        let alarm = store.alarms.first(where: { store.isAlarmEnabled($0) && $0.hasSound })
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
        guard let alarm = ringingAlarm else { return }
        if alarm.requiresWakeConfirmation,
           AppSettings.shared.wakeConfirmationEnabled,
           AppSettings.shared.wakeConfirmationMode == .calculus {
            stopAudioForCalculusConfirmation(alarm: alarm)
            return
        }
        if currentCandidate?.isTest != true {
            store.stopAlarm(alarm)
            AlarmNotificationManager.shared.remove(alarm: alarm)
        }
        audioManager.stop()
        finishCurrent()
    }

    /// Stops the sound while keeping the active confirmation session alive.
    /// Calculus confirmation must remain on screen after Stop; otherwise Stop
    /// would become an unintended way to bypass the challenge.
    private func stopAudioForCalculusConfirmation(alarm: AlarmItem) {
        if currentCandidate?.isTest != true,
           alarm.wakeConfirmationState == .pending {
            store.stopAlarm(alarm)
            AlarmNotificationManager.shared.remove(alarm: alarm)
        }
        audioManager.stop()
        maximumDurationTimer?.invalidate()
        maximumDurationTimer = nil
        isRinging = false
        showActiveCalculusConfirmation(for: alarm)
        scheduleNextDeadline()
    }

    func snoozeRinging(minutes: Int = 5) {
        guard let alarm = ringingAlarm else { return }
        if currentCandidate?.isTest != true {
            store.snooze(alarm, minutes: alarm.snoozeMinutes)
            AlarmNotificationManager.shared.remove(alarm: alarm)
        }
        audioManager.stop()
        finishCurrent()
    }

    func confirmWake() {
        guard let alarm = ringingAlarm else { return }
        completeWakeConfirmation(for: alarm, isTest: currentCandidate?.isTest == true)
        audioManager.stop()
        finishCurrent()
    }

    /// Opens the confirmation UI for an alarm whose audio has already stopped.
    /// This is used by the alarm row when the selected confirmation method is
    /// a calculus challenge, so the row cannot bypass the challenge.
    func reopenWakeConfirmation(for alarm: AlarmItem) {
        guard AppSettings.shared.wakeConfirmationEnabled,
              alarm.requiresWakeConfirmation,
              alarm.wakeConfirmationState == .pending
                || alarm.wakeConfirmationState == .stoppedWithoutConfirmation else { return }
        AlarmPopupController.show(
            alarm: alarm,
            onSnooze: { _ in },
            onStop: { _ in },
            onConfirmWake: { [weak self] selectedAlarm in
                self?.completeWakeConfirmation(for: selectedAlarm, isTest: false)
                AlarmPopupController.dismiss()
            },
            showsPlaybackActions: false
        )
    }

    private func showActiveCalculusConfirmation(for alarm: AlarmItem) {
        AlarmPopupController.show(
            alarm: alarm,
            onSnooze: { _ in },
            onStop: { _ in },
            onConfirmWake: { [weak self] _ in
                self?.confirmWake()
            },
            showsPlaybackActions: false
        )
    }

    private func completeWakeConfirmation(for alarm: AlarmItem, isTest: Bool) {
        if !isTest {
            store.confirmWake(id: alarm.id)
            AlarmNotificationManager.shared.remove(alarm: alarm)
        }
    }

    private func finishCurrent() {
        maximumDurationTimer?.invalidate()
        maximumDurationTimer = nil
        isRinging = false
        ringingAlarm = nil
        if let candidate = currentCandidate {
            if !candidate.isTest {
                AlarmNotificationManager.shared.remove(alarm: candidate.alarm)
            }
            claimedAlarmIDs.remove(candidate.alarm.id)
        }
        currentOccurrenceID = nil
        currentCandidate = nil
        AlarmPopupController.dismiss()
        startNextIfNeeded()
        scheduleNextDeadline()
    }

    private func diagnosticDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}
