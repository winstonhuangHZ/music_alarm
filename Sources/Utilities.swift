import Foundation

/// Allowed audio file extensions for import (.mp3 / .m4a only).
let musicFileTypes: [String] = ["mp3", "m4a"]

enum MissedAlarmPolicy: String, CaseIterable, Identifiable {
    case never = "Never"
    case fifteenMinutes = "15 minutes"
    case oneHour = "1 hour"
    case twoHours = "2 hours"
    case wakeOnly = "On wake only"

    var id: String { rawValue }
    var title: String { L(rawValue) }

    var catchUpWindow: TimeInterval? {
        switch self {
        case .never: return nil
        case .fifteenMinutes: return 15 * 60
        case .oneHour: return 60 * 60
        case .twoHours, .wakeOnly: return 2 * 60 * 60
        }
    }
}

enum WakeConfirmationMode: String, CaseIterable, Identifiable {
    case button = "Button"
    case shortWord = "Short word"
    case hold = "Hold for 3 seconds"
    case slide = "Slide to confirm"
    case mainWindow = "Main window"

    var id: String { rawValue }
    var title: String { L(rawValue) }
}

/// Shared date / fire-key helpers used by the alarm engine and store.
enum AlarmTimeUtil {
    static let fireFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f
    }()

    /// A unique key for the minute an alarm was fired, to prevent double-firing.
    static func fireKey(for date: Date) -> String {
        fireFormatter.string(from: date)
    }

    /// A short catch-up window prevents a stale alarm from firing days later,
    /// while still allowing a sleeping Mac or a late app wake-up to recover a
    /// missed occurrence.
    static let missedAlarmWindow: TimeInterval = 2 * 60 * 60
}
