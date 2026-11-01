import Foundation

@main
struct SharedAlarmStorageSmoke {
    static func main() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("music-alarm-storage-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let storage = SharedAlarmStorage(rootURL: root)
        let first = ["alarm": "07:30"]
        let second = ["alarm": "08:00"]
        precondition(storage.save(first, to: storage.alarmsURL))
        precondition(storage.loadResult([String: String].self, from: storage.alarmsURL).value == first)
        precondition(storage.save(second, to: storage.alarmsURL))

        try Data("{not-json".utf8).write(to: storage.alarmsURL)
        let recovered = storage.loadResult([String: String].self, from: storage.alarmsURL)
        precondition(recovered.status == .recoveredFromBackup)
        precondition(recovered.value == first)

        let legacyJSON = """
        [{"id":"\(UUID().uuidString)","hour":7,"minute":0,"repeatType":"Once","isEnabled":true,"tracks":[{"type":"spotify","link":"legacy"}]}]
        """.data(using: .utf8)!
        var migrated = try JSONDecoder().decode([AlarmItem].self, from: legacyJSON)[0]
        migrated.migrateIfNeeded()
        precondition(migrated.tracks.isEmpty)
        precondition(migrated.audioNeedsSelection)

        let confirmationRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("music-alarm-confirmation-\(UUID().uuidString)", isDirectory: true)
        let confirmationStorage = SharedAlarmStorage(rootURL: confirmationRoot)
        defer { try? FileManager.default.removeItem(at: confirmationRoot) }
        AppSettings.shared.wakeConfirmationEnabled = true
        AppSettings.shared.wakeConfirmationDeadlineMinutes = 30
        let confirmationStore = AlarmStore(storage: confirmationStorage)
        var confirmationAlarm = AlarmItem()
        confirmationAlarm.repeatType = .once
        confirmationAlarm.requiresWakeConfirmation = true
        confirmationStore.addAlarm(confirmationAlarm)
        confirmationStore.markPlaybackStarted(id: confirmationAlarm.id,
                                               occurrence: Date(),
                                               isSnooze: false)
        precondition(confirmationStore.occurrences.count == 1)
        precondition(confirmationStore.alarms[0].isEnabled)
        precondition(confirmationStore.alarms[0].wakeConfirmationState == .pending)
        confirmationStore.stopAlarm(confirmationAlarm)
        precondition(confirmationStore.alarms[0].wakeConfirmationState == .stoppedWithoutConfirmation)
        confirmationStore.confirmWake(id: confirmationAlarm.id)
        precondition(!confirmationStore.alarms[0].isEnabled)
        precondition(confirmationStore.alarms[0].wakeConfirmationState == .confirmed)
        precondition(confirmationStore.alarms[0].wakeStartedAt != nil)
        precondition(confirmationStore.alarms[0].wakeStoppedAt != nil)
        precondition(confirmationStore.alarms[0].wakeConfirmedAt != nil)
        precondition(confirmationStore.occurrences[0].outcome == .confirmed)

        let legacyAlarmJSON = """
        [{"hour":7,"minute":0,"repeatType":"Once","isEnabled":true,"tracks":[]}]
        """.data(using: .utf8)!
        let legacyAlarm = try JSONDecoder().decode([AlarmItem].self, from: legacyAlarmJSON)[0]
        precondition(!legacyAlarm.requiresWakeConfirmation)
        precondition(legacyAlarm.wakeConfirmationState == .none)

        let libraryRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("music-alarm-library-\(UUID().uuidString)", isDirectory: true)
        let libraryStorage = SharedAlarmStorage(rootURL: libraryRoot)
        defer { try? FileManager.default.removeItem(at: libraryRoot) }
        let libraryStore = AlarmStore(storage: libraryStorage)
        let audioID = UUID()
        libraryStore.importedAudios = [ImportedAudio(id: audioID, name: "Morning", urlString: "/missing/Morning.m4a")]
        var linkedAlarm = AlarmItem()
        linkedAlarm.tracks = [.local(name: "Morning", path: "/missing/Morning.m4a", audioID: audioID)]
        libraryStore.addAlarm(linkedAlarm)
        libraryStore.removeAudio(id: audioID)
        precondition(libraryStore.importedAudios.isEmpty)
        precondition(libraryStore.alarms[0].tracks.isEmpty)
        precondition(libraryStore.alarms[0].audioNeedsSelection)

        var datedAlarm = AlarmItem()
        datedAlarm.repeatType = .once
        datedAlarm.scheduledDate = Calendar.current.date(byAdding: .day, value: 2, to: Date())
        precondition(datedAlarm.nextFireDate() != nil)

        var customAlarm = AlarmItem()
        customAlarm.repeatType = .custom
        customAlarm.weekdays = [2, 4]
        precondition(customAlarm.nextFireDate() != nil)

        let legacyAudioJSON = "[{\"id\":\"\(UUID().uuidString)\",\"name\":\"Legacy\",\"urlString\":\"/tmp/legacy.m4a\"}]"
        let legacyAudios = try JSONDecoder().decode([ImportedAudio].self,
                                                      from: Data(legacyAudioJSON.utf8))
        precondition(legacyAudios[0].isManagedCopy)

        let backupParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("music-alarm-backup-parent-\(UUID().uuidString)", isDirectory: true)
        let backupTargetRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("music-alarm-backup-target-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: backupParent)
            try? FileManager.default.removeItem(at: backupTargetRoot)
        }
        let backupSourceStore = AlarmStore(storage: SharedAlarmStorage(rootURL: backupTargetRoot))
        var backupAlarm = AlarmItem()
        backupAlarm.label = "Backup test"
        backupAlarm.repeatType = .daily
        backupSourceStore.addAlarm(backupAlarm)
        backupSourceStore.pauseFor(hours: 2)
        let backupFolder = try BackupManager.export(store: backupSourceStore, to: backupParent)
        let backupPreview = try BackupManager.preview(from: backupFolder)
        precondition(backupPreview.manifest.formatVersion == 3)
        precondition(backupPreview.manifest.includesRuntimeState)
        precondition(backupPreview.runtimeState.pauseAllUntil != nil)
        precondition(FileManager.default.fileExists(atPath: backupFolder.appendingPathComponent("runtime.json").path))
        let restoredRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("music-alarm-restored-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: restoredRoot) }
        let restoredStore = AlarmStore(storage: SharedAlarmStorage(rootURL: restoredRoot))
        try BackupManager.importBackup(from: backupFolder, into: restoredStore)
        precondition(restoredStore.alarms.first?.label == "Backup test")
        precondition((restoredStore.pauseAllUntil ?? Date()) > Date())
        precondition(FileManager.default.fileExists(atPath: backupFolder.appendingPathComponent("occurrences.json").path))

        restoredStore.pauseFor(hours: 1)
        try BackupManager.importBackup(from: backupFolder, into: restoredStore, conflictPolicy: .merge)
        precondition((restoredStore.pauseAllUntil ?? Date()) > Date())

        var failedAlarm = AlarmItem()
        failedAlarm.label = "Failure test"
        failedAlarm.repeatType = .once
        let failedOccurrence = Date()
        restoredStore.addAlarm(failedAlarm)
        restoredStore.markPlaybackFailed(id: failedAlarm.id,
                                         occurrence: failedOccurrence,
                                         isSnooze: false,
                                         reason: "test failure")
        precondition(restoredStore.occurrences.contains {
            $0.alarmID == failedAlarm.id && $0.outcome == .failed && $0.failureReason == "test failure"
        })
        precondition(restoredStore.alarms.first(where: { $0.id == failedAlarm.id })?.isEnabled == false)

        let healthRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("music-alarm-health-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: healthRoot) }
        let healthStorage = SharedAlarmStorage(rootURL: healthRoot)
        try healthStorage.prepareDirectories()
        let orphanURL = healthStorage.audioDirectoryURL.appendingPathComponent("orphan.m4a")
        try Data("orphan".utf8).write(to: orphanURL)
        let healthStore = AlarmStore(storage: healthStorage)
        let firstAudio = ImportedAudio(name: "First", urlString: "/tmp/first.m4a",
                                       isManagedCopy: true, contentHash: "same-hash")
        let secondAudio = ImportedAudio(name: "Second", urlString: "/tmp/second.m4a",
                                        isManagedCopy: true, contentHash: "same-hash")
        healthStore.importedAudios = [firstAudio, secondAudio]
        let report = healthStore.audioLibraryReport()
        precondition(report.duplicateGroups.count == 1)
        precondition(report.orphanedManagedFiles.count == 1)
        precondition(healthStore.removeOrphanedManagedAudioFiles() == 1)
        precondition(healthStore.deduplicateAudioLibrary() == 1)
        precondition(healthStore.importedAudios.count == 1)

        let pauseRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("music-alarm-pause-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: pauseRoot) }
        let pauseStore = AlarmStore(storage: SharedAlarmStorage(rootURL: pauseRoot))
        var pauseAlarm = AlarmItem()
        pauseAlarm.repeatType = .once
        pauseAlarm.scheduledDate = Date().addingTimeInterval(3600)
        pauseStore.addAlarm(pauseAlarm)
        precondition(pauseStore.nextAlarmFire(at: Date()).date != nil)
        pauseStore.pauseFor(hours: 1)
        precondition(pauseStore.isPausedForAll)
        precondition((pauseStore.pauseAllUntil ?? Date()) > Date())
        precondition(pauseStore.nextAlarmFire(at: Date()).date == nil)
        let reloadedPauseStore = AlarmStore(storage: SharedAlarmStorage(rootURL: pauseRoot))
        precondition(reloadedPauseStore.pauseAllUntil == pauseStore.pauseAllUntil)
        reloadedPauseStore.resumeAll()
        precondition(!reloadedPauseStore.isPausedForAll)
        reloadedPauseStore.pauseToday()
        precondition(reloadedPauseStore.isPausedForAll)
        precondition((reloadedPauseStore.pauseAllUntil ?? Date()) > Date())
        reloadedPauseStore.resumeAll()
        reloadedPauseStore.temporarilyDisable(id: pauseAlarm.id,
                                              until: Date().addingTimeInterval(3600))
        precondition(!reloadedPauseStore.isAlarmEnabled(reloadedPauseStore.alarms[0]))
        precondition(reloadedPauseStore.nextAlarmFire(at: Date()).date == nil)
        reloadedPauseStore.resumeAlarm(id: pauseAlarm.id)
        precondition(reloadedPauseStore.isAlarmEnabled(reloadedPauseStore.alarms[0]))
        precondition(reloadedPauseStore.nextAlarmFire(at: Date()).date != nil)

        print("shared storage smoke test passed")
    }
}
