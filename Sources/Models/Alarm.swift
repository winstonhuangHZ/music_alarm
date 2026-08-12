import Foundation

/// How often an alarm repeats.
enum RepeatType: String, Codable, CaseIterable, Identifiable, Equatable, Hashable {
    case once = "Once"
    case daily = "Daily"
    case weekdays = "Weekdays"

    var id: String { rawValue }
    /// Localized display title.
    var title: String { L(rawValue) }
}

/// How an alarm plays its sound.
enum AlarmSoundSource: String, Codable, CaseIterable, Identifiable, Equatable, Hashable {
    case local = "Local Audio"
    case spotify = "Spotify Playlist"

    var id: String { rawValue }
    /// Localized display title.
    var title: String { L(rawValue) }
}

/// A single alarm. Persisted with JSON in UserDefaults.
struct AlarmItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var hour: Int = 7
    var minute: Int = 0
    var repeatType: RepeatType = .once
    var isEnabled: Bool = true
    var audioName: String?
    var audioPath: String?

    /// How the alarm sound is produced (local file vs. Spotify playlist).
    var soundSource: AlarmSoundSource = .local

    /// User-provided Spotify playlist link (URL or URI).
    /// Only used when `soundSource == .spotify`.
    var spotifyPlaylistURL: String?

    /// When a snoozed alarm should fire again (nil = not snoozed).
    var snoozeUntil: Date?

    /// Key of the minute in which the alarm was last fired (deduplication).
    var lastFiredKey: String = ""

    /// Locale-aware display string, e.g. "7:30 AM" (12 h) or "07:30" (24 h),
    /// following the user's regional time format.
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

    var hasAudio: Bool {
        guard let path = audioPath else { return false }
        return FileManager.default.fileExists(atPath: path)
    }

    /// Whether the alarm actually has a playable sound configured.
    var hasSound: Bool {
        switch soundSource {
        case .local: return hasAudio
        case .spotify:
            guard let link = spotifyPlaylistURL else { return false }
            return SpotifySupport.playlistID(from: link) != nil
        }
    }

    var audioDisplayName: String {
        switch soundSource {
        case .local:
            return audioName ?? L("No audio selected")
        case .spotify:
            guard let link = spotifyPlaylistURL else { return L("Spotify Playlist") }
            if let id = SpotifySupport.playlistID(from: link) {
                return String(format: L("Spotify Playlist · %@"), id)
            }
            return L("Spotify Playlist")
        }
    }

    var repeatText: String {
        repeatType.title
    }

    /// Next date this alarm will fire, based on its schedule and repeat type.
    func nextFireDate(from now: Date = Date()) -> Date? {
        if let snooze = snoozeUntil, snooze > now {
            return snooze
        }
        let cal = Calendar.current
        guard var next = cal.date(bySettingHour: hour, minute: minute, second: 0, of: now) else { return nil }
        if next <= now {
            guard let plus = cal.date(byAdding: .day, value: 1, to: next) else { return nil }
            next = plus
        }
        switch repeatType {
        case .once, .daily:
            return next
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
}
