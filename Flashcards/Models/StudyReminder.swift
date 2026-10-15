import Foundation
import UserNotifications

struct ReminderTime: Equatable {
    let hour: Int
    let minute: Int

    var dateComponents: DateComponents {
        DateComponents(hour: max(0, min(hour, 23)), minute: max(0, min(minute, 59)))
    }
}

protocol ReminderNotifications {
    func authorizationStatus() async -> UNAuthorizationStatus
    func requestPermission() async throws -> Bool
    func add(_ request: UNNotificationRequest) async throws
    func cancel(identifier: String)
}

struct SystemReminderNotifications: ReminderNotifications {
    let center = UNUserNotificationCenter.current()

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    func requestPermission() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .sound])
    }

    func add(_ request: UNNotificationRequest) async throws { try await center.add(request) }

    func cancel(identifier: String) {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
    }
}

enum StudyReminder {
    static let identifier = "flashies.daily-review"

    enum ReminderError: LocalizedError {
        case permissionDenied

        var errorDescription: String? {
            "Notifications are turned off for Flashies. Enable them in iOS Settings to receive study reminders."
        }
    }

    static func schedule(at time: ReminderTime, notifications: any ReminderNotifications = SystemReminderNotifications()) async throws {
        switch await notifications.authorizationStatus() {
        case .notDetermined:
            guard try await notifications.requestPermission() else {
                throw ReminderError.permissionDenied
            }
        case .denied:
            throw ReminderError.permissionDenied
        default:
            break
        }
        let content = UNMutableNotificationContent()
        content.title = "Time for Flashies"
        content.body = "A few minutes of review can help your learning stick. Open your due cards to get started."
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(dateMatching: time.dateComponents, repeats: true)
        try await notifications.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
    }

    static func cancel(notifications: any ReminderNotifications = SystemReminderNotifications()) {
        notifications.cancel(identifier: identifier)
    }
}
