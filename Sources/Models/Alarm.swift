import Foundation

/// How often an alarm repeats.
enum RepeatType: String, Codable, CaseIterable, Identifiable, Equatable, Hashable {
    case once = "Once"
    case daily = "Daily"
    case weekdays = "Weekdays"

    var id: String { rawValue }
    var title: String { L(rawValue) }
}

/// A single alarm. Persisted with JSON in UserDefaults.
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
        if let snooze = snoozeUntil, snooze > now { return snooze }
        let cal = Calendar.current
        guard var next = cal.date(bySettingHour: hour, minute: minute, second: 0, of: now) else { return nil }
        if next <= now {
            guard let plus = cal.date(byAdding: .day, value: 1, to: next) else { return nil }
            next = plus
        }
        switch repeatType {
        case .once, .daily: return next
        case .weekdays:
            var candidate = next
            while true {
                let wd = cal.component(.weekday, from: candidate)
                if (2...6).contains(wd) { return candidate }
                guard let c = cal.date(byAdding: .day, value: 1, to: candidate) else { return nil }
                candidate = c
            }
        }
    }

    // MARK: - Backwards-compat migration

    /// Call on first decode if `tracks` is empty but legacy fields exist, to
    /// populate the v2.1 tracks array from old v2.0 single-audio data.
    mutating func migrateIfNeeded() {
        guard tracks.isEmpty else { return }
        let source = soundSource ?? "local"
        if source == "spotify", let link = spotifyPlaylistURL, !link.isEmpty {
            tracks = [.spotify(link: link)]
        } else if let path = audioPath, let name = audioName, !path.isEmpty {
            tracks = [.local(name: name, path: path, audioID: id)]
        }
    }
}