import Foundation
import AppKit
import Combine

/// A user-imported audio file stored in the shared application data directory.
struct ImportedAudio: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var urlString: String

    var url: URL { URL(fileURLWithPath: urlString) }
    var fileExists: Bool { FileManager.default.fileExists(atPath: urlString) }
}

/// Central data store: alarms + imported audio library shared across app
/// versions and executable locations.
final class AlarmStore: ObservableObject {
    @Published var alarms: [AlarmItem] {
        didSet { save() }
    }
    @Published var importedAudios: [ImportedAudio] {
        didSet { save() }
    }

    private let storage: SharedAlarmStorage
    private let legacyAlarmsKey = "MusicAlarm.alarms.v1"
    private let legacyAudiosKey = "MusicAlarm.importedAudios.v1"
    private var alarmsNeedRepair = false
    private var importedAudiosNeedRepair = false

    init(storage: SharedAlarmStorage = .shared) {
        self.storage = storage

        if storage.containsSharedData() {
            let loadedAlarms = storage.loadResult([AlarmItem].self, from: storage.alarmsURL)
            let loadedAudios = storage.loadResult([ImportedAudio].self, from: storage.importedAudiosURL)

            alarmsNeedRepair = loadedAlarms.status == .invalid
            importedAudiosNeedRepair = loadedAudios.status == .invalid
            alarms = loadedAlarms.value ?? []
            importedAudios = loadedAudios.value ?? []

            migrateLoadedData()

            // A valid backup can repair a corrupted primary file. Never write an
            // empty array merely because a file was unreadable.
            if loadedAlarms.status == .recoveredFromBackup, let value = loadedAlarms.value {
                _ = storage.save(value, to: storage.alarmsURL)
                alarmsNeedRepair = false
            }
            if loadedAudios.status == .recoveredFromBackup, let value = loadedAudios.value {
                _ = storage.save(value, to: storage.importedAudiosURL)
                importedAudiosNeedRepair = false
            }
        } else {
            let legacyAlarms = Self.loadLegacy([AlarmItem].self, key: legacyAlarmsKey)
            var loadedAlarms = legacyAlarms.value ?? []
            for i in loadedAlarms.indices {
                loadedAlarms[i].migrateIfNeeded()
            }
            var loadedAudios = Self.loadLegacy([ImportedAudio].self, key: legacyAudiosKey).value ?? []
            storage.migrateLegacyAudio(alarms: &loadedAlarms, importedAudios: &loadedAudios)
            alarms = loadedAlarms
            importedAudios = loadedAudios

            // Do not replace unreadable legacy data with empty shared files.
            if !legacyAlarms.hadData || legacyAlarms.value != nil {
                save()
            } else {
                NSLog("AlarmStore: preserved unreadable legacy alarm data; no empty migration was written")
            }
        }
    }

    func save() {
        if !alarmsNeedRepair {
            _ = storage.save(alarms, to: storage.alarmsURL)
        } else {
            NSLog("AlarmStore: skipped saving unreadable alarms until the user changes the alarm list")
        }
        if !importedAudiosNeedRepair {
            _ = storage.save(importedAudios, to: storage.importedAudiosURL)
        } else {
            NSLog("AlarmStore: skipped saving unreadable audio library until the user changes it")
        }
    }

    /// Reloads the shared files so separate app copies can converge when one
    /// of them changes the alarm list. Invalid files are left untouched.
    func reloadFromSharedStorage() {
        let loadedAlarms = storage.loadResult([AlarmItem].self, from: storage.alarmsURL)
        let loadedAudios = storage.loadResult([ImportedAudio].self, from: storage.importedAudiosURL)

        if let value = loadedAlarms.value {
            alarmsNeedRepair = false
            alarms = value
        }
        if let value = loadedAudios.value {
            importedAudiosNeedRepair = false
            importedAudios = value
        }
        migrateLoadedData()
    }

    // MARK: - Alarms

    func addAlarm(_ alarm: AlarmItem) {
        alarms.append(alarm)
        persistAlarmsAfterUserChange()
    }

    func removeAlarm(_ alarm: AlarmItem) {
        alarms.removeAll { $0.id == alarm.id }
        persistAlarmsAfterUserChange()
    }

    /// Replaces an existing alarm in-place with an edited copy.
    func updateAlarm(_ alarm: AlarmItem) {
        guard let idx = alarms.firstIndex(where: { $0.id == alarm.id }) else { return }
        let old = alarms[idx]
        var updated = alarm
        let scheduleChanged = old.hour != alarm.hour
            || old.minute != alarm.minute
            || old.repeatType != alarm.repeatType
        if scheduleChanged {
            updated.snoozeUntil = nil
            updated.lastFiredKey = ""
        } else {
            updated.snoozeUntil = old.snoozeUntil
            updated.lastFiredKey = old.lastFiredKey
        }
        alarms[idx] = updated
        persistAlarmsAfterUserChange()
    }

    func toggleEnabled(id: UUID, enabled: Bool) {
        guard let idx = alarms.firstIndex(where: { $0.id == id }) else { return }
        alarms[idx].isEnabled = enabled
        if !enabled {
            alarms[idx].snoozeUntil = nil // cancels a pending snooze
        }
        persistAlarmsAfterUserChange()
    }

    func markFired(at index: Int, now: Date) {
        markPlaybackStarted(id: alarms[index].id, occurrence: now, isSnooze: false)
    }

    /// Records that playback or fallback actually started for an occurrence.
    /// The alarm is not consumed merely because the engine noticed it was due.
    func markPlaybackStarted(id: UUID, occurrence: Date, isSnooze: Bool) {
        guard let index = alarms.firstIndex(where: { $0.id == id }) else { return }
        if !isSnooze {
            alarms[index].lastFiredKey = AlarmTimeUtil.fireKey(for: occurrence)
        }
        alarms[index].snoozeUntil = nil
        if alarms[index].repeatType == .once {
            alarms[index].isEnabled = false
        }
        persistAlarmsAfterUserChange()
    }

    func snooze(_ alarm: AlarmItem, minutes: Int = 5) {
        guard let idx = alarms.firstIndex(where: { $0.id == alarm.id }) else { return }
        alarms[idx].snoozeUntil = Date().addingTimeInterval(TimeInterval(minutes * 60))
        // Keep the original occurrence key. Snooze is a continuation of that
        // occurrence and must not make the base alarm fire a second time.
        alarms[idx].isEnabled = true // re-armed so the snoozed alarm can fire
        persistAlarmsAfterUserChange()
    }

    func stopAlarm(_ alarm: AlarmItem) {
        guard let idx = alarms.firstIndex(where: { $0.id == alarm.id }) else { return }
        alarms[idx].snoozeUntil = nil
        if alarms[idx].repeatType == .once {
            alarms[idx].isEnabled = false
        }
        persistAlarmsAfterUserChange()
    }

    /// The soonest enabled alarm and its fire date.
    func nextAlarmFire(at now: Date = Date()) -> (alarm: AlarmItem?, date: Date?) {
        var bestAlarm: AlarmItem?
        var bestDate: Date?
        for alarm in alarms where alarm.isEnabled {
            let d: Date?
            if let snooze = alarm.snoozeUntil, snooze <= now {
                d = now
            } else if let occurrence = alarm.mostRecentOccurrence(at: now),
                      now.timeIntervalSince(occurrence) <= AlarmTimeUtil.missedAlarmWindow,
                      alarm.lastFiredKey != AlarmTimeUtil.fireKey(for: occurrence) {
                d = now
            } else {
                d = alarm.nextFireDate(from: now)
            }
            guard let d = d else { continue }
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
        let audioID = UUID()
        do {
            let sharedURL = try storage.copyAudio(from: url, audioID: audioID)
            let audio = ImportedAudio(id: audioID, name: name, urlString: sharedURL.path)
            importedAudios.append(audio)
            persistImportedAudiosAfterUserChange()
            return audio
        } catch {
            NSLog("AlarmStore: failed to copy imported audio %@: %@", url.path, error.localizedDescription)
            return nil
        }
    }

    func removeAudio(id: UUID) {
        importedAudios.removeAll { $0.id == id }
        persistImportedAudiosAfterUserChange()
    }

    private func migrateLoadedData() {
        var migratedAlarms = alarms
        for index in migratedAlarms.indices {
            migratedAlarms[index].migrateIfNeeded()
        }
        var migratedAudios = importedAudios
        storage.migrateLegacyAudio(alarms: &migratedAlarms, importedAudios: &migratedAudios)

        if migratedAlarms != alarms {
            alarms = migratedAlarms
            if !alarmsNeedRepair { _ = storage.save(alarms, to: storage.alarmsURL) }
        }
        if migratedAudios != importedAudios {
            importedAudios = migratedAudios
            if !importedAudiosNeedRepair { _ = storage.save(importedAudios, to: storage.importedAudiosURL) }
        }
    }

    private func persistAlarmsAfterUserChange() {
        alarmsNeedRepair = false
        _ = storage.save(alarms, to: storage.alarmsURL)
    }

    private func persistImportedAudiosAfterUserChange() {
        importedAudiosNeedRepair = false
        _ = storage.save(importedAudios, to: storage.importedAudiosURL)
    }

    private static func loadLegacy<T: Decodable>(_ type: T.Type, key: String)
        -> (value: T?, hadData: Bool) {
        guard let data = UserDefaults.standard.data(forKey: key) else {
            return (nil, false)
        }
        do {
            return (try JSONDecoder().decode(type, from: data), true)
        } catch {
            NSLog("AlarmStore: failed to decode legacy key %@: %@", key, error.localizedDescription)
            return (nil, true)
        }
    }
}
