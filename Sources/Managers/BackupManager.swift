import Foundation
import AppKit

struct MusicAlarmBackupManifest: Codable {
    let formatVersion: Int
    let createdAt: Date
    let appVersion: String
    let includesAudio: Bool
    let includesOccurrences: Bool
    let includesRuntimeState: Bool

    private enum CodingKeys: String, CodingKey {
        case formatVersion, createdAt, appVersion, includesAudio, includesOccurrences, includesRuntimeState
    }

    init(formatVersion: Int, createdAt: Date, appVersion: String,
         includesAudio: Bool, includesOccurrences: Bool, includesRuntimeState: Bool = false) {
        self.formatVersion = formatVersion
        self.createdAt = createdAt
        self.appVersion = appVersion
        self.includesAudio = includesAudio
        self.includesOccurrences = includesOccurrences
        self.includesRuntimeState = includesRuntimeState
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        formatVersion = try c.decode(Int.self, forKey: .formatVersion)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        appVersion = try c.decode(String.self, forKey: .appVersion)
        includesAudio = try c.decodeIfPresent(Bool.self, forKey: .includesAudio) ?? false
        includesOccurrences = try c.decodeIfPresent(Bool.self, forKey: .includesOccurrences) ?? false
        includesRuntimeState = try c.decodeIfPresent(Bool.self, forKey: .includesRuntimeState) ?? false
    }
}

enum BackupError: LocalizedError {
    case cancelled
    case invalidBackup(String)
    case destinationExists

    var errorDescription: String? {
        switch self {
        case .cancelled: return L("Backup operation cancelled")
        case .invalidBackup(let reason): return String(format: L("Invalid backup: %@"), reason)
        case .destinationExists: return L("Backup destination already exists")
        }
    }
}

enum BackupConflictPolicy: String, CaseIterable, Identifiable {
    case replace
    case merge

    var id: String { rawValue }
    var title: String { self == .replace ? L("Replace current data") : L("Merge with current data") }
}

struct BackupPreview {
    let manifest: MusicAlarmBackupManifest
    let alarmCount: Int
    let audioCount: Int
    let occurrenceCount: Int
    let missingAudioCount: Int
    let runtimeState: SharedAlarmRuntimeState

    var summary: String {
        String(format: L("%@ alarms, %@ audio items, %@ history records, %@ missing audio files"),
               "\(alarmCount)", "\(audioCount)", "\(occurrenceCount)", "\(missingAudioCount)")
    }
}

/// Exports and restores a complete user-readable backup directory. Audio paths
/// inside the backup are relative, so the backup can be restored after the app
/// is moved or the shared Application Support path changes.
enum BackupManager {
    static func exportInteractively(store: AlarmStore) throws -> URL {
        let panel = NSOpenPanel()
        panel.title = L("Choose a folder for the backup")
        panel.prompt = L("Export Backup")
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let parent = panel.url else { throw BackupError.cancelled }
        return try export(store: store, to: parent)
    }

    static func importInteractively(store: AlarmStore) throws -> URL {
        let panel = NSOpenPanel()
        panel.title = L("Choose a Music Alarm backup folder")
        panel.prompt = L("Choose Backup")
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let folder = panel.url else { throw BackupError.cancelled }
        try importBackup(from: folder, into: store, conflictPolicy: .replace)
        return folder
    }

    static func preview(from folder: URL) throws -> BackupPreview {
        let contents = try loadContents(from: folder)
        let missingAudioCount = contents.audios.filter {
            !FileManager.default.fileExists(atPath: folder.appendingPathComponent($0.urlString).path)
        }.count
        return BackupPreview(manifest: contents.manifest,
                             alarmCount: contents.alarms.count,
                             audioCount: contents.audios.count,
                             occurrenceCount: contents.occurrences.count,
                             missingAudioCount: missingAudioCount,
                             runtimeState: contents.runtimeState)
    }

    static func export(store: AlarmStore, to parent: URL) throws -> URL {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let folder = parent.appendingPathComponent("MusicAlarmBackup-\(formatter.string(from: Date()))",
                                                   isDirectory: true)
        guard !FileManager.default.fileExists(atPath: folder.path) else {
            throw BackupError.destinationExists
        }

        let fm = FileManager.default
        let audioFolder = folder.appendingPathComponent("Audio", isDirectory: true)
        try fm.createDirectory(at: audioFolder, withIntermediateDirectories: true)

        var audioCopies: [UUID: String] = [:]
        var exportedAudios: [ImportedAudio] = []
        for audio in store.importedAudios {
            let ext = audio.url.pathExtension.isEmpty ? "m4a" : audio.url.pathExtension.lowercased()
            let relative = "Audio/\(audio.id.uuidString).\(ext)"
            let destination = folder.appendingPathComponent(relative)
            if audio.fileExists {
                try fm.copyItem(at: audio.url, to: destination)
                audioCopies[audio.id] = relative
            }
            exportedAudios.append(ImportedAudio(id: audio.id,
                                                name: audio.name,
                                                urlString: relative,
                                                isManagedCopy: true))
        }

        var exportedAlarms = store.alarms
        for alarmIndex in exportedAlarms.indices {
            for trackIndex in exportedAlarms[alarmIndex].tracks.indices {
                guard case .local(let name, let path, let audioID) = exportedAlarms[alarmIndex].tracks[trackIndex]
                else { continue }
                if let relative = audioCopies[audioID] {
                    exportedAlarms[alarmIndex].tracks[trackIndex] = .local(name: name,
                                                                           path: relative,
                                                                           audioID: audioID)
                } else if FileManager.default.fileExists(atPath: path) {
                    let ext = URL(fileURLWithPath: path).pathExtension.isEmpty ? "m4a" : URL(fileURLWithPath: path).pathExtension.lowercased()
                    let relative = "Audio/\(audioID.uuidString).\(ext)"
                    let destination = folder.appendingPathComponent(relative)
                    if !fm.fileExists(atPath: destination.path) {
                        try fm.copyItem(at: URL(fileURLWithPath: path), to: destination)
                    }
                    exportedAlarms[alarmIndex].tracks[trackIndex] = .local(name: name,
                                                                           path: relative,
                                                                           audioID: audioID)
                }
            }
        }

        let manifest = MusicAlarmBackupManifest(formatVersion: 3,
                                                createdAt: Date(),
                                                appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown",
                                                includesAudio: true,
                                                includesOccurrences: true,
                                                includesRuntimeState: true)
        try write(manifest, to: folder.appendingPathComponent("manifest.json"))
        try write(exportedAlarms, to: folder.appendingPathComponent("alarms.json"))
        try write(exportedAudios, to: folder.appendingPathComponent("imported-audios.json"))
        try write(store.occurrences, to: folder.appendingPathComponent("occurrences.json"))
        try write(SharedAlarmRuntimeState(pauseAllUntil: store.pauseAllUntil),
                  to: folder.appendingPathComponent("runtime.json"))
        return folder
    }

    static func importBackup(from folder: URL, into store: AlarmStore,
                             conflictPolicy: BackupConflictPolicy = .replace) throws {
        let contents = try loadContents(from: folder)
        let backupAlarms = contents.alarms
        let backupAudios = contents.audios
        let backupOccurrences = contents.occurrences
        let backupRuntimeState = contents.runtimeState
        let fm = FileManager.default
        let storage = store.sharedStorage
        var pathMap: [UUID: String] = [:]
        var restoredAudios: [ImportedAudio] = []

        for audio in backupAudios {
            let relative = audio.urlString
            let source = folder.appendingPathComponent(relative)
            guard isContained(source, in: folder) else {
                throw BackupError.invalidBackup(L("An audio path escapes the backup folder"))
            }
            let destination: URL
            if fm.fileExists(atPath: source.path) {
                destination = try storage.copyAudio(from: source, audioID: audio.id)
            } else {
                let ext = source.pathExtension.isEmpty ? "m4a" : source.pathExtension
                destination = storage.audioDirectoryURL
                    .appendingPathComponent(audio.id.uuidString)
                    .appendingPathExtension(ext)
            }
            pathMap[audio.id] = destination.path
            restoredAudios.append(ImportedAudio(id: audio.id,
                                                name: audio.name,
                                                urlString: destination.path,
                                                isManagedCopy: true))
        }

        var restoredAlarms = backupAlarms
        for alarmIndex in restoredAlarms.indices {
            for trackIndex in restoredAlarms[alarmIndex].tracks.indices {
                guard case .local(let name, let path, let audioID) = restoredAlarms[alarmIndex].tracks[trackIndex]
                else { continue }
                let restoredPath = pathMap[audioID] ?? path
                restoredAlarms[alarmIndex].tracks[trackIndex] = .local(name: name,
                                                                       path: restoredPath,
                                                                       audioID: audioID)
            }
            restoredAlarms[alarmIndex].audioNeedsSelection = restoredAlarms[alarmIndex].tracks.isEmpty
                || !restoredAlarms[alarmIndex].tracks.contains(where: \.isPlayable)
        }
        switch conflictPolicy {
        case .replace:
            store.replaceDataFromBackup(alarms: restoredAlarms,
                                        importedAudios: restoredAudios,
                                        occurrences: backupOccurrences,
                                        runtimeState: backupRuntimeState)
        case .merge:
            var alarmMap = Dictionary(uniqueKeysWithValues: store.alarms.map { ($0.id, $0) })
            restoredAlarms.forEach { alarmMap[$0.id] = $0 }
            var audioMap = Dictionary(uniqueKeysWithValues: store.importedAudios.map { ($0.id, $0) })
            restoredAudios.forEach { audioMap[$0.id] = $0 }
            var occurrenceMap = Dictionary(uniqueKeysWithValues: store.occurrences.map { ($0.id, $0) })
            backupOccurrences.forEach { occurrenceMap[$0.id] = $0 }
            let mergedRuntimeState: SharedAlarmRuntimeState
            if let currentPause = store.pauseAllUntil, currentPause > Date() {
                mergedRuntimeState = SharedAlarmRuntimeState(pauseAllUntil: currentPause)
            } else {
                mergedRuntimeState = backupRuntimeState
            }
            store.replaceDataFromBackup(alarms: Array(alarmMap.values),
                                        importedAudios: Array(audioMap.values),
                                        occurrences: Array(occurrenceMap.values).sorted { $0.scheduledDate < $1.scheduledDate },
                                        runtimeState: mergedRuntimeState)
        }
    }

    private struct BackupContents {
        let manifest: MusicAlarmBackupManifest
        let alarms: [AlarmItem]
        let audios: [ImportedAudio]
        let occurrences: [AlarmOccurrence]
        let runtimeState: SharedAlarmRuntimeState
    }

    private static func loadContents(from folder: URL) throws -> BackupContents {
        let fm = FileManager.default
        let manifestURL = folder.appendingPathComponent("manifest.json")
        let alarmsURL = folder.appendingPathComponent("alarms.json")
        let audiosURL = folder.appendingPathComponent("imported-audios.json")
        guard fm.fileExists(atPath: manifestURL.path),
              fm.fileExists(atPath: alarmsURL.path),
              fm.fileExists(atPath: audiosURL.path) else {
            throw BackupError.invalidBackup(L("Required backup files are missing"))
        }
        let manifest = try read(MusicAlarmBackupManifest.self, from: manifestURL)
        guard manifest.formatVersion == 1 || manifest.formatVersion == 2 || manifest.formatVersion == 3 else {
            throw BackupError.invalidBackup(L("Unsupported backup format"))
        }
        let alarms = try read([AlarmItem].self, from: alarmsURL)
        let audios = try read([ImportedAudio].self, from: audiosURL)
        let occurrencesURL = folder.appendingPathComponent("occurrences.json")
        let occurrences: [AlarmOccurrence]
        let runtimeState: SharedAlarmRuntimeState
        if manifest.formatVersion >= 2 {
            guard fm.fileExists(atPath: occurrencesURL.path) else {
                throw BackupError.invalidBackup(L("Occurrence history is missing"))
            }
            occurrences = try read([AlarmOccurrence].self, from: occurrencesURL)
        } else {
            occurrences = []
        }
        if manifest.formatVersion >= 3 && manifest.includesRuntimeState {
            let runtimeURL = folder.appendingPathComponent("runtime.json")
            guard fm.fileExists(atPath: runtimeURL.path) else {
                throw BackupError.invalidBackup(L("Runtime state is missing"))
            }
            runtimeState = try read(SharedAlarmRuntimeState.self, from: runtimeURL)
        } else {
            runtimeState = SharedAlarmRuntimeState(pauseAllUntil: nil)
        }
        for audio in audios {
            let source = folder.appendingPathComponent(audio.urlString)
            guard isContained(source, in: folder) else {
                throw BackupError.invalidBackup(L("An audio path escapes the backup folder"))
            }
        }
        return BackupContents(manifest: manifest, alarms: alarms,
                              audios: audios, occurrences: occurrences,
                              runtimeState: runtimeState)
    }

    private static func write<T: Encodable>(_ value: T, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(value).write(to: url, options: .atomic)
    }

    private static func read<T: Decodable>(_ type: T.Type, from url: URL) throws -> T {
        try JSONDecoder().decode(type, from: Data(contentsOf: url))
    }

    private static func isContained(_ child: URL, in parent: URL) -> Bool {
        let childPath = child.standardizedFileURL.path
        let parentPath = parent.standardizedFileURL.path.hasSuffix("/")
            ? parent.standardizedFileURL.path
            : parent.standardizedFileURL.path + "/"
        return childPath.hasPrefix(parentPath)
    }
}
