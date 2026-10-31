import Foundation

/// Stable, app-instance-independent storage for alarms and imported audio.
/// Every Music Alarm build uses this same directory:
/// ~/Library/Application Support/Music Alarm/
final class SharedAlarmStorage {
    static let shared = SharedAlarmStorage()

    let rootURL: URL
    let audioDirectoryURL: URL
    let alarmsURL: URL
    let importedAudiosURL: URL

    private let fileManager: FileManager

    enum LoadStatus: Equatable {
        case missing
        case valid
        case recoveredFromBackup
        case invalid
    }

    struct LoadResult<Value> {
        let value: Value?
        let status: LoadStatus

        var isUsable: Bool { value != nil }
    }

    init(fileManager: FileManager = .default, rootURL: URL? = nil) {
        self.fileManager = fileManager
        if let rootURL {
            self.rootURL = rootURL
        } else {
            let appSupport = fileManager.urls(for: .applicationSupportDirectory,
                                              in: .userDomainMask).first
                ?? fileManager.homeDirectoryForCurrentUser
                    .appendingPathComponent("Library/Application Support", isDirectory: true)
            self.rootURL = appSupport.appendingPathComponent("Music Alarm", isDirectory: true)
        }
        audioDirectoryURL = self.rootURL.appendingPathComponent("Audio", isDirectory: true)
        alarmsURL = self.rootURL.appendingPathComponent("alarms.json")
        importedAudiosURL = self.rootURL.appendingPathComponent("imported-audios.json")
    }

    func prepareDirectories() throws {
        try fileManager.createDirectory(at: audioDirectoryURL,
                                        withIntermediateDirectories: true)
    }

    func containsSharedData() -> Bool {
        fileManager.fileExists(atPath: alarmsURL.path)
            || fileManager.fileExists(atPath: importedAudiosURL.path)
    }

    func loadResult<T: Decodable>(_ type: T.Type, from url: URL) -> LoadResult<T> {
        guard fileManager.fileExists(atPath: url.path) else {
            return LoadResult(value: nil, status: .missing)
        }

        if let value = decode(type, from: url) {
            return LoadResult(value: value, status: .valid)
        }

        let backupURL = url.appendingPathExtension("bak")
        if let value = decode(type, from: backupURL) {
            NSLog("SharedAlarmStorage: recovered %@ from backup", url.path)
            return LoadResult(value: value, status: .recoveredFromBackup)
        }

        NSLog("SharedAlarmStorage: no valid copy exists for %@; preserving the unreadable file", url.path)
        return LoadResult(value: nil, status: .invalid)
    }

    @discardableResult
    func save<T: Encodable>(_ value: T, to url: URL) -> Bool {
        do {
            try prepareDirectories()
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(value)

            // Keep the last known-good copy. Data.write(options: .atomic) protects
            // readers from partial files, while this backup protects against a
            // later interrupted write or manual corruption.
            let backupURL = url.appendingPathExtension("bak")
            if fileManager.fileExists(atPath: url.path) {
                try? fileManager.removeItem(at: backupURL)
                try? fileManager.copyItem(at: url, to: backupURL)
            }
            try data.write(to: url, options: .atomic)
            return true
        } catch {
            NSLog("SharedAlarmStorage: failed to save %@: %@", url.path, error.localizedDescription)
            return false
        }
    }

    func copyAudio(from sourceURL: URL, audioID: UUID) throws -> URL {
        try prepareDirectories()
        let ext = sourceURL.pathExtension.isEmpty ? "m4a" : sourceURL.pathExtension.lowercased()
        let destination = audioDirectoryURL
            .appendingPathComponent(audioID.uuidString)
            .appendingPathExtension(ext)
        if !fileManager.fileExists(atPath: destination.path) {
            try fileManager.copyItem(at: sourceURL, to: destination)
        }
        return destination
    }

    /// Copies legacy absolute-path audio into shared storage and rewrites
    /// every matching local track to its new stable path.
    func migrateLegacyAudio(alarms: inout [AlarmItem], importedAudios: inout [ImportedAudio]) {
        var pathMap: [String: String] = [:]

        for index in importedAudios.indices {
            let oldPath = importedAudios[index].urlString
            guard fileManager.fileExists(atPath: oldPath) else { continue }
            do {
                let destination = try copyAudio(from: URL(fileURLWithPath: oldPath),
                                                audioID: importedAudios[index].id)
                importedAudios[index].urlString = destination.path
                pathMap[oldPath] = destination.path
            } catch {
                NSLog("SharedAlarmStorage: failed to migrate %@: %@", oldPath, error.localizedDescription)
            }
        }

        for alarmIndex in alarms.indices {
            for trackIndex in alarms[alarmIndex].tracks.indices {
                guard case .local(let name, let path, let audioID) = alarms[alarmIndex].tracks[trackIndex]
                else { continue }
                if let newPath = pathMap[path] {
                    alarms[alarmIndex].tracks[trackIndex] = .local(name: name,
                                                                    path: newPath,
                                                                    audioID: audioID)
                }
            }

            guard alarms[alarmIndex].tracks.isEmpty,
                  let oldPath = alarms[alarmIndex].audioPath,
                  let name = alarms[alarmIndex].audioName,
                  fileManager.fileExists(atPath: oldPath) else { continue }
            do {
                let destination = try copyAudio(from: URL(fileURLWithPath: oldPath),
                                                audioID: alarms[alarmIndex].id)
                alarms[alarmIndex].tracks = [.local(name: name,
                                                     path: destination.path,
                                                     audioID: alarms[alarmIndex].id)]
            } catch {
                NSLog("SharedAlarmStorage: failed to migrate alarm audio %@: %@",
                      oldPath, error.localizedDescription)
            }
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            NSLog("SharedAlarmStorage: failed to decode %@: %@", url.path, error.localizedDescription)
            return nil
        }
    }
}
