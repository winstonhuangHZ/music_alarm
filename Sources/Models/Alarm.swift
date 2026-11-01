import Foundation

/// How often an alarm repeats.
enum RepeatType: String, Codable, CaseIterable, Identifiable, Equatable, Hashable {
    case once = "Once"
    case daily = "Daily"
    case weekdays = "Weekdays"
    case custom = "Custom"

    var id: String { rawValue }
    var title: String { L(rawValue) }
}

enum WakeConfirmationState: String, Codable, Equatable {
    case none = "None"
    case pending = "Wake-up pending"
    case confirmed = "Wake-up confirmed"
    case stoppedWithoutConfirmation = "Wake-up not confirmed"
    case expired = "Wake-up confirmation expired"
}

/// A single alarm. Persisted with JSON in the shared Application Support store.
struct AlarmItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var hour: Int = 7
    var minute: Int = 0
    var repeatType: RepeatType = .once
    var isEnabled: Bool = true
    var label: String = ""
    var scheduledDate: Date?
    /// Calendar weekday values use Foundation's convention: Sunday = 1.
    var weekdays: Set<Int> = []
    var requiresWakeConfirmation: Bool = false
    var wakeConfirmationState: WakeConfirmationState = .none
    var wakeStartedAt: Date?
    var wakeStoppedAt: Date?
    var wakeConfirmedAt: Date?
    var wakeConfirmationDeadline: Date?
    var skipNextOccurrenceKey: String = ""
    var snoozeMinutes: Int = 5

    var fadeDurationSeconds: Int = 20
    var targetVolumePercent: Int = 85
    /// Zero means no automatic maximum duration.
    var maximumPlaybackMinutes: Int = 30
    var loopsPlaylist: Bool = true

    // ---- v2.1 playlist model ----
    /// Ordered list of local audio tracks.
    var tracks: [AudioTrack] = []

    /// Set when an older external audio record was migrated away.
    var audioNeedsSelection: Bool = false

    // ---- v2.0 single-audio fields (kept for backwards compatibility) ----
    var audioName: String?
    var audioPath: String?

    /// Deprecated; use tracks array instead.
    var soundSource: String? = nil

    /// Deprecated; use tracks array instead.
    var spotifyPlaylistURL: String?

    // ---- runtime state ----
    var snoozeUntil: Date?
    var lastFiredKey: String = ""

    private enum CodingKeys: String, CodingKey {
        case id, hour, minute, repeatType, isEnabled, label, scheduledDate, weekdays
        case requiresWakeConfirmation, wakeConfirmationState
        case wakeStartedAt, wakeStoppedAt, wakeConfirmedAt, wakeConfirmationDeadline
        case skipNextOccurrenceKey, snoozeMinutes
        case fadeDurationSeconds, targetVolumePercent, maximumPlaybackMinutes, loopsPlaylist
        case tracks, audioNeedsSelection
        case audioName, audioPath, soundSource, spotifyPlaylistURL
        case snoozeUntil, lastFiredKey
    }

    init() {}

    /// Decode current and legacy records without requiring newly introduced
    /// fields to exist in older JSON data.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        hour = try c.decodeIfPresent(Int.self, forKey: .hour) ?? 7
        minute = try c.decodeIfPresent(Int.self, forKey: .minute) ?? 0
        repeatType = try c.decodeIfPresent(RepeatType.self, forKey: .repeatType) ?? .once
        isEnabled = try c.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        label = try c.decodeIfPresent(String.self, forKey: .label) ?? ""
        scheduledDate = try c.decodeIfPresent(Date.self, forKey: .scheduledDate)
        weekdays = try c.decodeIfPresent(Set<Int>.self, forKey: .weekdays) ?? []
        requiresWakeConfirmation = try c.decodeIfPresent(Bool.self, forKey: .requiresWakeConfirmation) ?? false
        wakeConfirmationState = try c.decodeIfPresent(WakeConfirmationState.self, forKey: .wakeConfirmationState) ?? .none
        wakeStartedAt = try c.decodeIfPresent(Date.self, forKey: .wakeStartedAt)
        wakeStoppedAt = try c.decodeIfPresent(Date.self, forKey: .wakeStoppedAt)
        wakeConfirmedAt = try c.decodeIfPresent(Date.self, forKey: .wakeConfirmedAt)
        wakeConfirmationDeadline = try c.decodeIfPresent(Date.self, forKey: .wakeConfirmationDeadline)
        skipNextOccurrenceKey = try c.decodeIfPresent(String.self, forKey: .skipNextOccurrenceKey) ?? ""
        snoozeMinutes = try c.decodeIfPresent(Int.self, forKey: .snoozeMinutes) ?? 5
        fadeDurationSeconds = try c.decodeIfPresent(Int.self, forKey: .fadeDurationSeconds) ?? 20
        targetVolumePercent = try c.decodeIfPresent(Int.self, forKey: .targetVolumePercent) ?? 85
        maximumPlaybackMinutes = try c.decodeIfPresent(Int.self, forKey: .maximumPlaybackMinutes) ?? 30
        loopsPlaylist = try c.decodeIfPresent(Bool.self, forKey: .loopsPlaylist) ?? true
        tracks = try c.decodeIfPresent([AudioTrack].self, forKey: .tracks) ?? []
        audioNeedsSelection = try c.decodeIfPresent(Bool.self, forKey: .audioNeedsSelection) ?? false
        audioName = try c.decodeIfPresent(String.self, forKey: .audioName)
        audioPath = try c.decodeIfPresent(String.self, forKey: .audioPath)
        soundSource = try c.decodeIfPresent(String.self, forKey: .soundSource)
        spotifyPlaylistURL = try c.decodeIfPresent(String.self, forKey: .spotifyPlaylistURL)
        snoozeUntil = try c.decodeIfPresent(Date.self, forKey: .snoozeUntil)
        lastFiredKey = try c.decodeIfPresent(String.self, forKey: .lastFiredKey) ?? ""
    }

    // MARK: - Display

    var timeString: String {
        var comps = DateComponents()
        comps.hour = hour
        comps.minute = minute
        guard let date = Calendar.current.date(from: comps) else {
            return String(format: "%02d:%02d", hour, minute)
        }
        let f = DateFormatter()
        f.locale = Locale.current
        f.dateStyle = .none
        f.timeStyle = .short
        return f.string(from: date)
    }

    /// Whether the alarm actually has at least one playable sound configured.
    var hasSound: Bool {
        tracks.contains { $0.isPlayable }
    }

    /// Compact summary shown in the alarm row.
    var audioDisplayName: String {
        if tracks.isEmpty { return audioNeedsSelection ? L("Choose local audio") : L("No audio selected") }
        if tracks.count == 1 { return tracks[0].displayName }
        return String(format: L("%d tracks"), tracks.count)
    }

    /// Count of tracks grouped by source for display.
    var sourceSummary: String {
        let local = tracks.filter { if case .local = $0 { return true }; return false }.count
        if local > 0 { return "🎵 \(local)" }
        return L("No audio")
    }

    var repeatText: String {
        switch repeatType {
        case .custom:
            let symbols = Calendar.current.veryShortWeekdaySymbols
            let names = weekdays.sorted().compactMap { index in
                symbols.indices.contains(index - 1) ? symbols[index - 1] : nil
            }
            return names.isEmpty ? L("Custom") : names.joined(separator: " ")
        default:
            return repeatType.title
        }
    }

    // MARK: - Next fire date

    func nextFireDate(from now: Date = Date()) -> Date? {
        if let snooze = snoozeUntil {
            return snooze > now ? snooze : now
        }
        let candidate = nextScheduledDate(from: now)
        if let candidate,
           skipNextOccurrenceKey == AlarmTimeUtil.fireKey(for: candidate) {
            return nextScheduledDate(from: candidate.addingTimeInterval(60))
        }
        return candidate
    }

    private func nextScheduledDate(from now: Date) -> Date? {
        let cal = Calendar.current
        guard let today = scheduledDate(on: now, calendar: cal) else { return nil }
        switch repeatType {
        case .once:
            if let scheduledDate { return scheduledDate > now ? scheduledDate : nil }
            return today > now ? today : nil
        case .daily:
            if today > now { return today }
            return cal.date(byAdding: .day, value: 1, to: today)
        case .weekdays, .custom:
            let allowedDays: Set<Int> = repeatType == .weekdays ? Set(2...6) : weekdays
            guard !allowedDays.isEmpty else { return nil }
            var candidate = today > now
                ? today
                : (cal.date(byAdding: .day, value: 1, to: today) ?? today)
            while true {
                let wd = cal.component(.weekday, from: candidate)
                if allowedDays.contains(wd) { return candidate }
                guard let c = cal.date(byAdding: .day, value: 1, to: candidate) else { return nil }
                candidate = c
            }
        }
    }

    /// Returns the most recent scheduled occurrence at or before `now`.
    /// The engine uses this to recover from timer gaps and system wake-up.
    func mostRecentOccurrence(at now: Date = Date()) -> Date? {
        if let snooze = snoozeUntil, snooze <= now { return snooze }
        let candidate = mostRecentScheduledOccurrence(at: now)
        if let candidate,
           skipNextOccurrenceKey == AlarmTimeUtil.fireKey(for: candidate) {
            return mostRecentScheduledOccurrence(at: candidate.addingTimeInterval(-60))
        }
        return candidate
    }

    private func mostRecentScheduledOccurrence(at now: Date) -> Date? {
        let cal = Calendar.current
        if repeatType == .once, let scheduledDate {
            return scheduledDate <= now ? scheduledDate : nil
        }
        var candidate: Date
        if let today = scheduledDate(on: now, calendar: cal), today <= now {
            candidate = today
        } else {
            guard let yesterday = cal.date(byAdding: .day, value: -1, to: now),
                  let previous = scheduledDate(on: yesterday, calendar: cal) else { return nil }
            candidate = previous
        }

        switch repeatType {
        case .once, .daily:
            return candidate
        case .weekdays, .custom:
            let allowedDays: Set<Int> = repeatType == .weekdays ? Set(2...6) : weekdays
            guard !allowedDays.isEmpty else { return nil }
            var weekdayCandidate = candidate
            while true {
                let wd = cal.component(.weekday, from: weekdayCandidate)
                if allowedDays.contains(wd) { return weekdayCandidate }
                guard let previous = cal.date(byAdding: .day, value: -1, to: weekdayCandidate),
                      let scheduled = scheduledDate(on: previous, calendar: cal) else { return nil }
                weekdayCandidate = scheduled
            }
        }
    }

    private func scheduledDate(on day: Date, calendar: Calendar) -> Date? {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)
    }

    // MARK: - Backwards-compat migration

    /// Call on first decode if `tracks` is empty but legacy fields exist, to
    /// populate the v2.1 tracks array from old v2.0 single-audio data.
    mutating func migrateIfNeeded() {
        if tracks.contains(where: {
            if case .unavailable = $0 { return true }
            return false
        }) {
            tracks.removeAll {
                if case .unavailable = $0 { return true }
                return false
            }
            audioNeedsSelection = true
        }
        guard tracks.isEmpty else { return }
        let source = (soundSource ?? "local").lowercased()
        if source == "spotify" || source == "spotify playlist" {
            audioNeedsSelection = true
            soundSource = nil
            spotifyPlaylistURL = nil
        } else if let path = audioPath, let name = audioName, !path.isEmpty {
            tracks = [.local(name: name, path: path, audioID: id)]
        }
    }
}
