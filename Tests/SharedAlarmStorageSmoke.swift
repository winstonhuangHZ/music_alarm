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
        let confirmationStore = AlarmStore(storage: confirmationStorage)
        var confirmationAlarm = AlarmItem()
        confirmationAlarm.repeatType = .once
        confirmationAlarm.requiresWakeConfirmation = true
        confirmationStore.addAlarm(confirmationAlarm)
        confirmationStore.markPlaybackStarted(id: confirmationAlarm.id,
                                               occurrence: Date(),
                                               isSnooze: false)
        precondition(confirmationStore.alarms[0].isEnabled)
        precondition(confirmationStore.alarms[0].wakeConfirmationState == .pending)
        confirmationStore.stopAlarm(confirmationAlarm)
        precondition(confirmationStore.alarms[0].wakeConfirmationState == .stoppedWithoutConfirmation)
        confirmationStore.confirmWake(id: confirmationAlarm.id)
        precondition(!confirmationStore.alarms[0].isEnabled)
        precondition(confirmationStore.alarms[0].wakeConfirmationState == .confirmed)

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

        print("shared storage smoke test passed")
    }
}
