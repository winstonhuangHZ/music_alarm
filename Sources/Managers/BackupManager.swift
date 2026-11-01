import Foundation
import AppKit

struct MusicAlarmBackupManifest: Codable {
    let formatVersion: Int
    let createdAt: Date
    let appVersion: String
    let includesAudio: Bool
    let includesOccurrences: Bool

    private enum CodingKeys: String, CodingKey {
        case formatVersion, createdAt, appVersion, includesAudio, includesOccurrences
    }

    init(formatVersion: Int, createdAt: Date, appVersion: String,
         includesAudio: Bool, includesOccurrences: Bool) {
        self.formatVersion = formatVersion
        self.createdAt = createdAt
        self.appVersion = appVersion
        self.includesAudio = includesAudio
        self.includesOccurrences = includesOccurrences
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        formatVersion = try c.decode(Int.self, forKey: .formatVersion)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        appVersion = try c.decode(String.self, forKey: .appVersion)
        includesAudio = try c.decodeIfPresent(Bool.self, forKey: .includesAudio) ?? false
        includesOccurrences = try c.decodeIfPresent(Bool.self, forKey: .includesOccurrences) ?? false
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
        try importBackup(from: folder, into: store)
        return folder
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

        let manifest = MusicAlarmBackupManifest(formatVersion: 2,
                                                createdAt: Date(),
                                                appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown",
                                                includesAudio: true,
                                                includesOccurrences: true)
        try write(manifest, to: folder.appendingPathComponent("manifest.json"))
        try write(exportedAlarms, to: folder.appendingPathComponent("alarms.json"))
        try write(exportedAudios, to: folder.appendingPathComponent("imported-audios.json"))
        try write(store.occurrences, to: folder.appendingPathComponent("occurrences.json"))
        return folder
    }

    static func importBackup(from folder: URL, into store: AlarmStore) throws {
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
        guard manifest.formatVersion == 1 || manifest.formatVersion == 2 else {
            throw BackupError.invalidBackup(L("Unsupported backup format"))
        }
        let backupAlarms = try read([AlarmItem].self, from: alarmsURL)
        let backupAudios = try read([ImportedAudio].self, from: audiosURL)
        let backupOccurrences: [AlarmOccurrence]
        let occurrencesURL = folder.appendingPathComponent("occurrences.json")
        if manifest.formatVersion >= 2 {
            guard fm.fileExists(atPath: occurrencesURL.path) else {
                throw BackupError.invalidBackup(L("Occurrence history is missing"))
            }
            backupOccurrences = try read([AlarmOccurrence].self, from: occurrencesURL)
        } else {
            backupOccurrences = []
        }
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
        store.replaceDataFromBackup(alarms: restoredAlarms,
                                    importedAudios: restoredAudios,
                                    occurrences: backupOccurrences)
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
