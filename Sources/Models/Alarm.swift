import Foundation

/// How often an alarm repeats.
enum RepeatType: String, Codable, CaseIterable, Identifiable, Equatable, Hashable {
    case once = "Once"
    case daily = "Daily"
    case weekdays = "Weekdays"

    var id: String { rawValue }
    var title: String { L(rawValue) }
}

/// A single alarm. Persisted with JSON in the shared Application Support store.
struct AlarmItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var hour: Int = 7
    var minute: Int = 0
    var repeatType: RepeatType = .once
    var isEnabled: Bool = true

    // ---- v2.1 playlist model ----
    /// Ordered list of audio tracks for this alarm (local + Spotify links mixed).
    var tracks: [AudioTrack] = []

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
        case id, hour, minute, repeatType, isEnabled, tracks
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
        tracks = try c.decodeIfPresent([AudioTrack].self, forKey: .tracks) ?? []
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
        if tracks.isEmpty { return L("No audio selected") }
        if tracks.count == 1 { return tracks[0].displayName }
        return String(format: L("%d tracks"), tracks.count)
    }

    /// Count of tracks grouped by source for display.
    var sourceSummary: String {
        let local = tracks.filter { if case .local = $0 { return true }; return false }.count
        let spotify = tracks.count - local
        if local > 0 && spotify > 0 { return "🎵\(local) 🎧\(spotify)" }
        if local > 0 { return "🎵 \(local)" }
        if spotify > 0 { return "🎧 \(spotify)" }
        return L("No audio")
    }

    var repeatText: String { repeatType.title }

    // MARK: - Next fire date

    func nextFireDate(from now: Date = Date()) -> Date? {
        if let snooze = snoozeUntil {
            return snooze > now ? snooze : now
        }
        let cal = Calendar.current
        guard let today = scheduledDate(on: now, calendar: cal) else { return nil }
        switch repeatType {
        case .once:
            return today > now ? today : nil
        case .daily:
            if today > now { return today }
            return cal.date(byAdding: .day, value: 1, to: today)
        case .weekdays:
            var candidate = today > now
                ? today
                : (cal.date(byAdding: .day, value: 1, to: today) ?? today)
            while true {
                let wd = cal.component(.weekday, from: candidate)
                if (2...6).contains(wd) { return candidate }
                guard let c = cal.date(byAdding: .day, value: 1, to: candidate) else { return nil }
                candidate = c
            }
        }
    }

    /// Returns the most recent scheduled occurrence at or before `now`.
    /// The engine uses this to recover from timer gaps and system wake-up.
    func mostRecentOccurrence(at now: Date = Date()) -> Date? {
        if let snooze = snoozeUntil, snooze <= now { return snooze }
        let cal = Calendar.current
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
        case .weekdays:
            var weekdayCandidate = candidate
            while true {
                let wd = cal.component(.weekday, from: weekdayCandidate)
                if (2...6).contains(wd) { return weekdayCandidate }
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
        guard tracks.isEmpty else { return }
        let source = (soundSource ?? "local").lowercased()
        if (source == "spotify" || source == "spotify playlist"),
           let link = spotifyPlaylistURL, !link.isEmpty {
            tracks = [.spotify(link: link)]
        } else if let path = audioPath, let name = audioName, !path.isEmpty {
            tracks = [.local(name: name, path: path, audioID: id)]
        }
    }
}
