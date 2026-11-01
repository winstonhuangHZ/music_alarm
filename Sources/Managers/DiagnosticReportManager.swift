import AppKit

enum DiagnosticReportManager {
    static func exportInteractively(store: AlarmStore, engine: AlarmEngine) throws -> URL {
        let panel = NSSavePanel()
        panel.title = L("Export diagnostic report")
        panel.nameFieldStringValue = "MusicAlarm-Diagnostics.txt"
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else {
            throw CocoaError(.userCancelled)
        }

        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        let next = store.nextAlarmFire(at: Date())
        let nextText = next.date.map { formatter.string(from: $0) } ?? L("No upcoming alarm")
        let buildInfoURL = Bundle.main.url(forResource: "MusicAlarm.build-info", withExtension: nil)
        let buildInfo = buildInfoURL.flatMap { try? String(contentsOf: $0, encoding: .utf8) }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) } ?? "unavailable"
        let lines = [
            "Music Alarm diagnostics",
            "Generated: \(formatter.string(from: Date()))",
            "Version: \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown")",
            "Build metadata: \(buildInfo)",
            "System: \(ProcessInfo.processInfo.operatingSystemVersionString)",
            "Locale: \(Locale.current.identifier)",
            "Time zone: \(TimeZone.current.identifier)",
            "Next alarm: \(nextText)",
            "Alarm count: \(store.alarms.count)",
            "Imported audio count: \(store.importedAudios.count)",
            "Occurrence count: \(store.occurrences.count)",
            "Shared storage: ~/Library/Application Support/Music Alarm",
            "Scheduler: \(engine.lastDiagnostic)",
            "Output device and volume: see Reliability Check",
        ]
        try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
