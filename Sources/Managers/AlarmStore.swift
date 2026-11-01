import Foundation
import AppKit
import Combine
import AVFoundation

/// A user-imported audio file stored in the shared application data directory.
struct ImportedAudio: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var urlString: String
    var isManagedCopy: Bool = true

    var url: URL { URL(fileURLWithPath: urlString) }
    var fileExists: Bool { FileManager.default.fileExists(atPath: urlString) }

    private enum CodingKeys: String, CodingKey { case id, name, urlString, isManagedCopy }

    init(id: UUID = UUID(), name: String, urlString: String, isManagedCopy: Bool = true) {
        self.id = id
        self.name = name
        self.urlString = urlString
        self.isManagedCopy = isManagedCopy
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decode(String.self, forKey: .name)
        urlString = try c.decode(String.self, forKey: .urlString)
        isManagedCopy = try c.decodeIfPresent(Bool.self, forKey: .isManagedCopy) ?? true
    }
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
    var sharedStorage: SharedAlarmStorage { storage }
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

        // Preserve the behavior of pre-2.10 alarms that already opted into
        // wake confirmation while making the feature explicitly controllable
        // for new installations from Settings.
        if alarms.contains(where: { $0.requiresWakeConfirmation }) {
            AppSettings.shared.wakeConfirmationEnabled = true
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

    func replaceDataFromBackup(alarms: [AlarmItem], importedAudios: [ImportedAudio]) {
        alarmsNeedRepair = false
        importedAudiosNeedRepair = false
        self.alarms = alarms
        self.importedAudios = importedAudios
        persistAlarmsAfterUserChange()
        persistImportedAudiosAfterUserChange()
    }

    /// Replaces an existing alarm in-place with an edited copy.
    func updateAlarm(_ alarm: AlarmItem) {
        guard let idx = alarms.firstIndex(where: { $0.id == alarm.id }) else { return }
        let old = alarms[idx]
        var updated = alarm
        let scheduleChanged = old.hour != alarm.hour
            || old.minute != alarm.minute
            || old.repeatType != alarm.repeatType
            || old.scheduledDate != alarm.scheduledDate
            || old.weekdays != alarm.weekdays
        if scheduleChanged {
            updated.snoozeUntil = nil
            updated.lastFiredKey = ""
            updated.skipNextOccurrenceKey = ""
            updated.wakeConfirmationState = .none
            updated.wakeStartedAt = nil
            updated.wakeStoppedAt = nil
            updated.wakeConfirmedAt = nil
            updated.wakeConfirmationDeadline = nil
        } else {
            updated.snoozeUntil = old.snoozeUntil
            updated.lastFiredKey = old.lastFiredKey
            updated.skipNextOccurrenceKey = old.skipNextOccurrenceKey
            if old.requiresWakeConfirmation != alarm.requiresWakeConfirmation {
                updated.wakeConfirmationState = .none
                updated.wakeStartedAt = nil
                updated.wakeStoppedAt = nil
                updated.wakeConfirmedAt = nil
                updated.wakeConfirmationDeadline = nil
            } else {
                updated.wakeStartedAt = old.wakeStartedAt
                updated.wakeStoppedAt = old.wakeStoppedAt
                updated.wakeConfirmedAt = old.wakeConfirmedAt
                updated.wakeConfirmationDeadline = old.wakeConfirmationDeadline
            }
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
            if alarms[index].skipNextOccurrenceKey == AlarmTimeUtil.fireKey(for: occurrence) {
                alarms[index].skipNextOccurrenceKey = ""
            }
        }
        alarms[index].snoozeUntil = nil
        let requiresConfirmation = alarms[index].requiresWakeConfirmation
            && AppSettings.shared.wakeConfirmationEnabled
        if requiresConfirmation {
            let startedAt = Date()
            alarms[index].wakeStartedAt = startedAt
            alarms[index].wakeStoppedAt = nil
            alarms[index].wakeConfirmedAt = nil
            alarms[index].wakeConfirmationDeadline = AppSettings.shared.wakeConfirmationDeadlineMinutes
                .flatMap { startedAt.addingTimeInterval(TimeInterval($0 * 60)) }
            alarms[index].wakeConfirmationState = .pending
        } else {
            clearWakeConfirmationState(at: index)
        }
        if alarms[index].repeatType == .once && !requiresConfirmation {
            alarms[index].isEnabled = false
        }
        persistAlarmsAfterUserChange()
    }

    func snooze(_ alarm: AlarmItem, minutes: Int? = nil) {
        guard let idx = alarms.firstIndex(where: { $0.id == alarm.id }) else { return }
        let actualMinutes = max(1, minutes ?? alarms[idx].snoozeMinutes)
        alarms[idx].snoozeUntil = Date().addingTimeInterval(TimeInterval(actualMinutes * 60))
        // Keep the original occurrence key. Snooze is a continuation of that
        // occurrence and must not make the base alarm fire a second time.
        alarms[idx].isEnabled = true // re-armed so the snoozed alarm can fire
        persistAlarmsAfterUserChange()
    }

    func skipNext(id: UUID) {
        guard let idx = alarms.firstIndex(where: { $0.id == id }) else { return }
        if alarms[idx].repeatType == .once {
            alarms[idx].isEnabled = false
            alarms[idx].snoozeUntil = nil
        } else {
            alarms[idx].snoozeUntil = nil
            if let next = alarms[idx].nextFireDate(from: Date()) {
                alarms[idx].skipNextOccurrenceKey = AlarmTimeUtil.fireKey(for: next)
            }
        }
        persistAlarmsAfterUserChange()
    }

    func stopAlarm(_ alarm: AlarmItem) {
        guard let idx = alarms.firstIndex(where: { $0.id == alarm.id }) else { return }
        alarms[idx].snoozeUntil = nil
        if alarms[idx].requiresWakeConfirmation && AppSettings.shared.wakeConfirmationEnabled,
           alarms[idx].wakeConfirmationState == .pending {
            alarms[idx].wakeConfirmationState = .stoppedWithoutConfirmation
            alarms[idx].wakeStoppedAt = Date()
            // Keep a one-shot alarm enabled until the user explicitly confirms
            // the wake-up from the alarm row.
            persistAlarmsAfterUserChange()
            return
        }
        if alarms[idx].repeatType == .once {
            alarms[idx].isEnabled = false
        }
        persistAlarmsAfterUserChange()
    }

    func confirmWake(id: UUID) {
        guard let idx = alarms.firstIndex(where: { $0.id == id }),
              alarms[idx].requiresWakeConfirmation,
              AppSettings.shared.wakeConfirmationEnabled else { return }
        if let deadline = alarms[idx].wakeConfirmationDeadline, deadline < Date() {
            alarms[idx].wakeConfirmationState = .expired
            persistAlarmsAfterUserChange()
            return
        }
        alarms[idx].wakeConfirmationState = .confirmed
        alarms[idx].wakeConfirmedAt = Date()
        if alarms[idx].repeatType == .once {
            alarms[idx].isEnabled = false
        }
        persistAlarmsAfterUserChange()
    }

    private func clearWakeConfirmationState(at index: Int) {
        alarms[index].wakeConfirmationState = .none
        alarms[index].wakeStartedAt = nil
        alarms[index].wakeStoppedAt = nil
        alarms[index].wakeConfirmedAt = nil
        alarms[index].wakeConfirmationDeadline = nil
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
                      isRecentMissedOccurrence(occurrence, now: now),
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

    private func isRecentMissedOccurrence(_ occurrence: Date, now: Date) -> Bool {
        let age = now.timeIntervalSince(occurrence)
        if age < 0 || age <= 2 { return age >= 0 }
        let policy = AppSettings.shared.missedAlarmPolicy
        guard policy != .wakeOnly, let window = policy.catchUpWindow else { return false }
        return age <= window
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
        guard isPlayableAudio(url: url) else {
            NSLog("AlarmStore: rejected audio that AVAudioPlayer cannot decode: %@", url.path)
            return nil
        }
        if let existing = importedAudios.first(where: { sameFile($0.url, url) }) {
            return existing
        }
        let audioID = UUID()
        do {
            let shouldCopy = AppSettings.shared.copyImportedAudioToLibrary
            let storedURL: URL
            let managedCopy: Bool
            if shouldCopy {
                storedURL = try storage.copyAudio(from: url, audioID: audioID)
                managedCopy = true
            } else {
                storedURL = url.standardizedFileURL
                managedCopy = false
            }
            let audio = ImportedAudio(id: audioID,
                                      name: name,
                                      urlString: storedURL.path,
                                      isManagedCopy: managedCopy)
            importedAudios.append(audio)
            persistImportedAudiosAfterUserChange()
            return audio
        } catch {
            NSLog("AlarmStore: failed to copy imported audio %@: %@", url.path, error.localizedDescription)
            return nil
        }
    }

    func removeAudio(id: UUID) {
        let removedAudio = importedAudios.first(where: { $0.id == id })
        importedAudios.removeAll { $0.id == id }
        for index in alarms.indices {
            let originalCount = alarms[index].tracks.count
            alarms[index].tracks.removeAll {
                if case .local(_, _, let audioID) = $0 { return audioID == id }
                return false
            }
            if alarms[index].tracks.count != originalCount {
                alarms[index].audioNeedsSelection = true
            }
        }
        if removedAudio?.isManagedCopy == true {
            storage.removeAudioFile(for: id)
        }
        persistAlarmsAfterUserChange()
        persistImportedAudiosAfterUserChange()
    }

    /// Replaces the shared copy while keeping the stable audio ID referenced by
    /// existing alarms.
    @discardableResult
    func replaceAudio(id: UUID) -> ImportedAudio? {
        guard let index = importedAudios.firstIndex(where: { $0.id == id }) else { return nil }
        let panel = NSOpenPanel()
        panel.title = L("Replace Audio")
        panel.prompt = L("Replace")
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedFileTypes = musicFileTypes
        guard panel.runModal() == .OK, let sourceURL = panel.url,
              isPlayableAudio(url: sourceURL) else { return nil }
        do {
            let managedCopy = importedAudios[index].isManagedCopy
            let storedURL: URL
            if managedCopy {
                storedURL = try storage.replaceAudio(from: sourceURL, audioID: id)
            } else {
                storedURL = sourceURL.standardizedFileURL
            }
            importedAudios[index].name = sourceURL.deletingPathExtension().lastPathComponent
            importedAudios[index].urlString = storedURL.path
            for alarmIndex in alarms.indices {
                for trackIndex in alarms[alarmIndex].tracks.indices {
                    if case .local(_, _, let audioID) = alarms[alarmIndex].tracks[trackIndex], audioID == id {
                        alarms[alarmIndex].tracks[trackIndex] = .local(name: importedAudios[index].name,
                                                                       path: storedURL.path,
                                                                       audioID: audioID)
                        alarms[alarmIndex].audioNeedsSelection = false
                    }
                }
            }
            persistAlarmsAfterUserChange()
            persistImportedAudiosAfterUserChange()
            return importedAudios[index]
        } catch {
            NSLog("AlarmStore: failed to replace audio %@: %@", sourceURL.path, error.localizedDescription)
            return nil
        }
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

    private func isPlayableAudio(url: URL) -> Bool {
        guard FileManager.default.fileExists(atPath: url.path),
              let player = try? AVAudioPlayer(contentsOf: url) else { return false }
        return player.duration > 0
    }

    private func sameFile(_ lhs: URL, _ rhs: URL) -> Bool {
        if lhs.standardizedFileURL == rhs.standardizedFileURL { return true }
        guard let left = try? lhs.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey]),
              let right = try? rhs.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey]) else { return false }
        return left.fileSize == right.fileSize
            && left.contentModificationDate == right.contentModificationDate
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
