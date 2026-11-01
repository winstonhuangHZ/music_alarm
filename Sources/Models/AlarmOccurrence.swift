import Foundation

/// The final result of one concrete alarm occurrence.
enum AlarmOccurrenceOutcome: String, Codable, CaseIterable, Identifiable {
    case started
    case stopped
    case confirmed
    case snoozed
    case failed
    case expired

    var id: String { rawValue }
    var title: String { L(rawValue.capitalized) }
}

/// A durable record of what happened for one scheduled alarm occurrence.
/// Keeping this separate from AlarmItem prevents runtime history from being
/// overwritten when the user edits the next schedule.
struct AlarmOccurrence: Identifiable, Codable, Equatable {
    var id = UUID()
    var alarmID: UUID
    var label: String
    var scheduledDate: Date
    var actualStartedAt: Date?
    var stoppedAt: Date?
    var confirmedAt: Date?
    var timezoneIdentifier: String
    var utcOffsetSeconds: Int
    var wasDaylightSavingTime: Bool
    var isSnooze: Bool
    var outcome: AlarmOccurrenceOutcome
    var failureReason: String?
    var usedFallback: Bool
    var attemptedTracks: [String]

    init(id: UUID = UUID(), alarmID: UUID, label: String, scheduledDate: Date,
         actualStartedAt: Date? = nil, stoppedAt: Date? = nil,
         confirmedAt: Date? = nil, timezone: TimeZone = .current,
         isSnooze: Bool, outcome: AlarmOccurrenceOutcome,
         failureReason: String? = nil, usedFallback: Bool = false,
         attemptedTracks: [String] = []) {
        self.id = id
        self.alarmID = alarmID
        self.label = label
        self.scheduledDate = scheduledDate
        self.actualStartedAt = actualStartedAt
        self.stoppedAt = stoppedAt
        self.confirmedAt = confirmedAt
        self.timezoneIdentifier = timezone.identifier
        self.utcOffsetSeconds = timezone.secondsFromGMT(for: scheduledDate)
        self.wasDaylightSavingTime = timezone.isDaylightSavingTime(for: scheduledDate)
        self.isSnooze = isSnooze
        self.outcome = outcome
        self.failureReason = failureReason
        self.usedFallback = usedFallback
        self.attemptedTracks = attemptedTracks
    }
}
