import AppKit
import Darwin

/// Keeps one Music Alarm process active per user account. Other app copies are
/// still allowed to be opened, but they activate the existing process and exit.
final class SingleInstanceGuard {
    private var fileDescriptor: Int32 = -1

    func acquire() -> Bool {
        let supportDirectory = FileManager.default.urls(for: .applicationSupportDirectory,
                                                         in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support", isDirectory: true)
        let directory = supportDirectory.appendingPathComponent("Music Alarm", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: directory,
                                                     withIntermediateDirectories: true)
        } catch {
            NSLog("SingleInstanceGuard: failed to create lock directory: %@", error.localizedDescription)
            return true
        }

        let lockURL = directory.appendingPathComponent("app.lock")
        fileDescriptor = open(lockURL.path, O_RDWR | O_CREAT, mode_t(0o600))
        guard fileDescriptor >= 0 else {
            NSLog("SingleInstanceGuard: failed to open lock file")
            return true
        }

        if flock(fileDescriptor, LOCK_EX | LOCK_NB) == 0 {
            return true
        }

        close(fileDescriptor)
        fileDescriptor = -1
        return false
    }

    func release() {
        guard fileDescriptor >= 0 else { return }
        flock(fileDescriptor, LOCK_UN)
        close(fileDescriptor)
        fileDescriptor = -1
    }

    static func activateExistingInstance() {
        let bundleID = Bundle.main.bundleIdentifier ?? "com.musicalarm.app"
        let currentPID = ProcessInfo.processInfo.processIdentifier
        let existing = NSWorkspace.shared.runningApplications.first {
            $0.processIdentifier != currentPID && $0.bundleIdentifier == bundleID
        }
        existing?.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
    }

    deinit { release() }
}
