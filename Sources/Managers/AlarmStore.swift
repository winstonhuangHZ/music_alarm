import Foundation
import AppKit
import Combine

/// A user-imported audio file (path is persisted; playback resolves it lazily).
struct ImportedAudio: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var urlString: String

    var url: URL { URL(fileURLWithPath: urlString) }
    var fileExists: Bool { FileManager.default.fileExists(atPath: urlString) }
}

/// Central data store: alarms + imported audio library, persisted in UserDefaults.
final class AlarmStore: ObservableObject {
    @Published var alarms: [AlarmItem] {
        didSet { save() }
    }
    @Published var importedAudios: [ImportedAudio] {
        didSet { save() }
    }

    private let alarmsKey = "MusicAlarm.alarms.v1"
    private let audiosKey = "MusicAlarm.importedAudios.v1"

    init() {
        var loadedAlarms: [AlarmItem] = []
        if let data = UserDefaults.standard.data(forKey: alarmsKey),
           let decoded = try? JSONDecoder().decode([AlarmItem].self, from: data) {
            loadedAlarms = decoded
        }
        // Migrate v2.0 single-audio data → v2.1 tracks array
        for i in loadedAlarms.indices {
            loadedAlarms[i].migrateIfNeeded()
        }
        alarms = loadedAlarms

        if let data = UserDefaults.standard.data(forKey: audiosKey),
           let decoded = try? JSONDecoder().decode([ImportedAudio].self, from: data) {
            importedAudios = decoded
        } else {
            importedAudios = []
        }
    }

    func save() {
        if let data = try? JSONEncoder().encode(alarms) {
            UserDefaults.standard.set(data, forKey: alarmsKey)
        }
        if let data = try? JSONEncoder().encode(importedAudios) {
            UserDefaults.standard.set(data, forKey: audiosKey)
        }
        // Force a synchronous flush to disk so alarms / imported music survive
        // an immediate app quit or crash right after a mutation.
        UserDefaults.standard.synchronize()
    }

    // MARK: - Alarms

    func addAlarm(_ alarm: AlarmItem) {
        alarms.append(alarm)
    }

    func removeAlarm(_ alarm: AlarmItem) {
        alarms.removeAll { $0.id == alarm.id }
    }

    /// Replaces an existing alarm in-place with an edited copy.
    func updateAlarm(_ alarm: AlarmItem) {
        guard let idx = alarms.firstIndex(where: { $0.id == alarm.id }) else { return }
        // Preserve runtime state (snooze / last-fire dedup flag) when editing.
        var updated = alarm
        updated.snoozeUntil = alarms[idx].snoozeUntil
        updated.lastFiredKey = alarms[idx].lastFiredKey
        alarms[idx] = updated
    }

    func toggleEnabled(id: UUID, enabled: Bool) {
        guard let idx = alarms.firstIndex(where: { $0.id == id }) else { return }
        alarms[idx].isEnabled = enabled
        if !enabled {
            alarms[idx].snoozeUntil = nil // cancels a pending snooze
        }
    }

    func markFired(at index: Int, now: Date) {
        alarms[index].lastFiredKey = AlarmTimeUtil.fireKey(for: now)
        alarms[index].snoozeUntil = nil
        if alarms[index].repeatType == .once {
            alarms[index].isEnabled = false
        }
    }

    func snooze(_ alarm: AlarmItem, minutes: Int = 5) {
        guard let idx = alarms.firstIndex(where: { $0.id == alarm.id }) else { return }
        alarms[idx].snoozeUntil = Date().addingTimeInterval(TimeInterval(minutes * 60))
        alarms[idx].lastFiredKey = ""
        alarms[idx].isEnabled = true // re-armed so the snoozed alarm can fire
    }

    func stopAlarm(_ alarm: AlarmItem) {
        guard let idx = alarms.firstIndex(where: { $0.id == alarm.id }) else { return }
        alarms[idx].snoozeUntil = nil
        if alarms[idx].repeatType == .once {
            alarms[idx].isEnabled = false
        }
    }

    /// The soonest enabled alarm and its fire date.
    func nextAlarmFire(at now: Date = Date()) -> (alarm: AlarmItem?, date: Date?) {
        var bestAlarm: AlarmItem?
        var bestDate: Date?
        for alarm in alarms where alarm.isEnabled {
            guard let d = alarm.nextFireDate(from: now) else { continue }
            if let bd = bestDate {
                if d < bd {
                    bestDate = d
                    bestAlarm = alarm
                }
            } else {
                bestDate = d
                bestAlarm = alarm
            }
        }
        return (bestAlarm, bestDate)
    }

    // MARK: - Audio library

    /// Opens the native macOS file picker restricted to .mp3 / .m4a.
    /// Returns the imported audio (or nil if the user cancelled / already imported).
    @discardableResult
    func importAudio() -> ImportedAudio? {
        let panel = NSOpenPanel()
        panel.title = L("Import Music")
        panel.prompt = L("Import")
        panel.message = L("Select an .mp3 or .m4a audio file")
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedFileTypes = musicFileTypes
        if panel.runModal() == .OK, let url = panel.url {
            return addImportedAudio(url: url)
        }
        return nil
    }

    /// Adds an audio file to the library. Returns nil if it was already present.
    @discardableResult
    func addImportedAudio(url: URL) -> ImportedAudio? {
        let name = url.deletingPathExtension().lastPathComponent
        guard !importedAudios.contains(where: { $0.urlString == url.path }) else {
            return importedAudios.first(where: { $0.urlString == url.path })
        }
        let audio = ImportedAudio(name: name, urlString: url.path)
        importedAudios.append(audio)
        return audio
    }

    func removeAudio(id: UUID) {
        importedAudios.removeAll { $0.id == id }
    }
}
