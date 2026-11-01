import AppKit
import UserNotifications

/// Delivers native macOS notification actions for a ringing alarm.
final class AlarmNotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = AlarmNotificationManager()

    private weak var engine: AlarmEngine?
    private var authorizationRequested = false

    private override init() {
        super.init()
    }

    func configure(engine: AlarmEngine) {
        self.engine = engine
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.setNotificationCategories([category(requiresConfirmation: false),
                                          category(requiresConfirmation: true)])
    }

    private func category(requiresConfirmation: Bool) -> UNNotificationCategory {
        let stop = UNNotificationAction(identifier: "MUSIC_ALARM_STOP",
                                         title: L("Stop"),
                                         options: [.foreground])
        let snooze = UNNotificationAction(identifier: "MUSIC_ALARM_SNOOZE",
                                          title: L("Snooze"),
                                          options: [.foreground])
        var actions = [snooze, stop]
        if requiresConfirmation {
            actions.append(UNNotificationAction(identifier: "MUSIC_ALARM_CONFIRM",
                                                 title: L("Confirm wake-up"),
                                                 options: [.foreground]))
        }
        return UNNotificationCategory(identifier: categoryIdentifier(requiresConfirmation: requiresConfirmation),
                                      actions: actions,
                                      intentIdentifiers: [],
                                      options: [.customDismissAction])
    }

    private func categoryIdentifier(requiresConfirmation: Bool) -> String {
        requiresConfirmation ? "MUSIC_ALARM_RINGING_CONFIRM" : "MUSIC_ALARM_RINGING"
    }

    func notify(alarm: AlarmItem) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { [weak self] settings in
            guard let self else { return }
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                self.scheduleNotification(for: alarm)
            case .notDetermined:
                guard !self.authorizationRequested else { return }
                self.authorizationRequested = true
                center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                    if let error {
                        NSLog("AlarmNotificationManager: authorization failed: %@", error.localizedDescription)
                    }
                    if granted {
                        self.scheduleNotification(for: alarm)
                    }
                }
            case .denied:
                break
            @unknown default:
                break
            }
        }
    }

    private func scheduleNotification(for alarm: AlarmItem) {
        guard engine?.ringingAlarm?.id == alarm.id else { return }
        let content = UNMutableNotificationContent()
        content.title = L("Time to wake up!")
        content.body = alarm.label.isEmpty ? alarm.audioDisplayName : alarm.label
        let requiresConfirmation = alarm.requiresWakeConfirmation && AppSettings.shared.wakeConfirmationEnabled
        content.categoryIdentifier = categoryIdentifier(requiresConfirmation: requiresConfirmation)
        content.threadIdentifier = "music-alarm"

        let request = UNNotificationRequest(identifier: "music-alarm-\(alarm.id.uuidString)",
                                             content: content,
                                             trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                NSLog("AlarmNotificationManager: failed to deliver notification: %@", error.localizedDescription)
            }
        }
    }

    func remove(alarm: AlarmItem) {
        let identifier = "music-alarm-\(alarm.id.uuidString)"
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                completionHandler()
                return
            }
            let alarmIDText = response.notification.request.identifier.replacingOccurrences(
                of: "music-alarm-", with: "")
            guard let alarmID = UUID(uuidString: alarmIDText),
                  self.engine?.ringingAlarm?.id == alarmID else {
                completionHandler()
                return
            }
            switch response.actionIdentifier {
            case "MUSIC_ALARM_STOP":
                self.engine?.stopRinging()
            case "MUSIC_ALARM_SNOOZE":
                self.engine?.snoozeRinging()
            case "MUSIC_ALARM_CONFIRM":
                guard self.engine?.ringingAlarm?.requiresWakeConfirmation == true,
                      AppSettings.shared.wakeConfirmationEnabled else {
                    completionHandler()
                    return
                }
                self.engine?.confirmWake()
            default:
                NSApp.activate(ignoringOtherApps: true)
            }
            completionHandler()
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        if #available(macOS 11.0, *) {
            completionHandler([.banner, .sound, .list])
        } else {
            completionHandler([.sound])
        }
    }
}
