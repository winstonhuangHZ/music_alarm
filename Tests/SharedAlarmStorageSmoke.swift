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
        print("shared storage smoke test passed")
    }
}
