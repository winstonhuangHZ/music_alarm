import Foundation

/// Allowed audio file extensions for import (.mp3 / .m4a only).
let musicFileTypes: [String] = ["mp3", "m4a"]

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
}
