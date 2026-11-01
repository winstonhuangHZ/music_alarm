import SwiftUI
import AppKit
import AVFoundation
import CoreAudio

/// A preflight page for checking whether the next alarm is likely to work.
/// The check is intentionally read-only apart from creating the shared data
/// directory when it has not been created yet.
struct ReliabilityCheckView: View {
    @ObservedObject var settings: AppSettings
    @EnvironmentObject var store: AlarmStore
    @EnvironmentObject var engine: AlarmEngine
    @Environment(\.presentationMode) private var presentationMode

    @State private var results: [ReliabilityCheckResult] = []
    @State private var isChecking = false
    @State private var checkedAt: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label(L("Reliability Check"), systemImage: "checkmark.shield")
                    .font(.title2.weight(.semibold))
                Spacer()
                Button(L("Run Check")) {
                    runCheck()
                }
                .buttonStyle(BorderedButtonStyle())
                .disabled(isChecking)
            }

            Text(L("Run this before sleep to check whether the next alarm has a usable audio path and a working scheduler."))
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let checkedAt {
                Text(String(format: L("Last checked %@"), dateString(checkedAt)))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            if results.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "checkmark.shield")
                        .font(.system(size: 34, weight: .medium))
                        .foregroundColor(.secondary)
                    Text(L("No check has been run"))
                        .font(.headline)
                    Text(L("Run a reliability check to inspect the next alarm and audio path."))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(results) { result in
                            resultRow(result)
                        }
                    }
                }
            }

            HStack {
                Spacer()
                Button(L("Close")) {
                    presentationMode.wrappedValue.dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
        }
        .padding(24)
        .frame(width: 640, height: 620)
        .onAppear {
            if results.isEmpty {
                runCheck()
            }
        }
    }

    @ViewBuilder
    private func resultRow(_ result: ReliabilityCheckResult) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: result.severity.systemImage)
                .foregroundColor(result.severity.color)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(result.title)
                    .font(.subheadline.weight(.semibold))
                Text(result.detail)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    }

    private func runCheck() {
        isChecking = true
        results = Self.check(
            store: store,
            engine: engine,
            settings: settings
        )
        checkedAt = Date()
        isChecking = false
    }

    private static func check(
        store: AlarmStore,
        engine: AlarmEngine,
        settings: AppSettings
    ) -> [ReliabilityCheckResult] {
        let now = Date()
        var results: [ReliabilityCheckResult] = []
        let enabledAlarms = store.alarms.filter { store.isAlarmEnabled($0, now: now) }
        let next = store.nextAlarmFire(at: now)

        if let nextAlarm = next.alarm, let date = next.date {
            let label = nextAlarm.label.isEmpty ? nextAlarm.timeString : nextAlarm.label
            results.append(.pass(
                title: L("Next alarm"),
                detail: String(format: L("%@ at %@"), label, dateString(date))
            ))
        } else if enabledAlarms.isEmpty {
            results.append(.warning(
                title: L("Next alarm"),
                detail: L("No enabled alarms are scheduled.")
            ))
        } else {
            results.append(.warning(
                title: L("Next alarm"),
                detail: L("Enabled alarms do not have a future occurrence.")
            ))
        }

        let fallbackName = settings.fallbackSoundChoice.rawValue
        let fallbackAvailable = NSSound(named: fallbackName) != nil
        results.append(
            fallbackAvailable
                ? .pass(title: L("Fallback sound"), detail: String(format: L("%@ is available."), fallbackName))
                : .failure(title: L("Fallback sound"), detail: String(format: L("%@ is not available."), fallbackName))
        )

        let unusableLibraryAudio = store.importedAudios.filter { audio in
            guard audio.fileExists else { return true }
            guard let player = try? AVAudioPlayer(contentsOf: audio.url) else { return true }
            return player.duration <= 0
        }
        if unusableLibraryAudio.isEmpty {
            results.append(.pass(
                title: L("Audio library"),
                detail: String(format: L("%@ imported audio items are present and playable."), store.importedAudios.count)
            ))
        } else {
            results.append(.warning(
                title: L("Audio library"),
                detail: String(format: L("%@ imported audio items need attention."), unusableLibraryAudio.count)
            ))
        }

        let alarmsWithoutPlayableTrack = enabledAlarms.filter { !$0.hasSound }
        if alarmsWithoutPlayableTrack.isEmpty {
            results.append(.pass(
                title: L("Alarm audio"),
                detail: String(format: L("%@ enabled alarms have a playable track."), enabledAlarms.count)
            ))
        } else if fallbackAvailable {
            results.append(.warning(
                title: L("Alarm audio"),
                detail: String(format: L("%@ enabled alarms have no playable track; fallback will be used."), alarmsWithoutPlayableTrack.count)
            ))
        } else {
            results.append(.failure(
                title: L("Alarm audio"),
                detail: String(format: L("%@ enabled alarms have no playable track or fallback."), alarmsWithoutPlayableTrack.count)
            ))
        }

        let output = defaultOutputDevice()
        if let output {
            let volumeText = output.volume.map { String(format: "%.0f%%", $0 * 100) } ?? L("volume unavailable")
            results.append(.pass(
                title: L("Output device"),
                detail: String(format: L("%@, system volume %@."), output.name, volumeText)
            ))
        } else {
            results.append(.failure(
                title: L("Output device"),
                detail: L("No default audio output device could be read.")
            ))
        }

        do {
            try store.sharedStorage.prepareDirectories()
            let root = store.sharedStorage.rootURL.path
            if FileManager.default.isWritableFile(atPath: root) {
                results.append(.pass(
                    title: L("Shared storage"),
                    detail: String(format: L("Shared data is writable at %@."), root)
                ))
            } else {
                results.append(.failure(
                    title: L("Shared storage"),
                    detail: String(format: L("Shared data is not writable at %@."), root)
                ))
            }
        } catch {
            results.append(.failure(
                title: L("Shared storage"),
                detail: error.localizedDescription
            ))
        }

        if !engine.lastDiagnostic.isEmpty {
            results.append(.pass(
                title: L("Scheduler"),
                detail: L("The scheduler has checked the current system time and is active.")
            ))
        } else {
            results.append(.warning(
                title: L("Scheduler"),
                detail: L("The scheduler has not reported an event yet.")
            ))
        }

        return results
    }

    private struct OutputDevice {
        let name: String
        let volume: Float32?
    }

    private static func defaultOutputDevice() -> OutputDevice? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size,
            &deviceID
        ) == noErr else { return nil }

        address.mSelector = kAudioObjectPropertyName
        var unmanagedName: Unmanaged<CFString>?
        size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(
            deviceID,
            &address,
            0,
            nil,
            &size,
            &unmanagedName
        ) == noErr,
        let unmanagedName else { return nil }

        address.mSelector = kAudioDevicePropertyVolumeScalar
        address.mScope = kAudioObjectPropertyScopeOutput
        address.mElement = kAudioObjectPropertyElementMain
        var volume = Float32(0)
        size = UInt32(MemoryLayout<Float32>.size)
        let volumeStatus = AudioObjectGetPropertyData(
            deviceID,
            &address,
            0,
            nil,
            &size,
            &volume
        )

        return OutputDevice(
            name: unmanagedName.takeUnretainedValue() as String,
            volume: volumeStatus == noErr ? volume : nil
        )
    }

    private static func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func dateString(_ date: Date) -> String {
        Self.dateString(date)
    }
}

private struct ReliabilityCheckResult: Identifiable {
    enum Severity {
        case pass
        case warning
        case failure

        var systemImage: String {
            switch self {
            case .pass: return "checkmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .failure: return "xmark.octagon.fill"
            }
        }

        var color: Color {
            switch self {
            case .pass: return .green
            case .warning: return .orange
            case .failure: return .red
            }
        }
    }

    let id = UUID()
    let severity: Severity
    let title: String
    let detail: String

    static func pass(title: String, detail: String) -> Self {
        Self(severity: .pass, title: title, detail: detail)
    }

    static func warning(title: String, detail: String) -> Self {
        Self(severity: .warning, title: title, detail: detail)
    }

    static func failure(title: String, detail: String) -> Self {
        Self(severity: .failure, title: title, detail: detail)
    }
}
