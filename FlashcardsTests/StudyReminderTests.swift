import Testing
import UserNotifications
@testable import Flashcards

private final class FakeNotifications: ReminderNotifications {
    var status = UNAuthorizationStatus.notDetermined
    var grantsPermission = true
    var permissionRequests = 0
    var added: [UNNotificationRequest] = []
    var cancelled: [String] = []

    func authorizationStatus() async -> UNAuthorizationStatus { status }
    func requestPermission() async throws -> Bool {
        permissionRequests += 1
        return grantsPermission
    }
    func add(_ request: UNNotificationRequest) async throws { added.append(request) }
    func cancel(identifier: String) { cancelled.append(identifier) }
}

struct StudyReminderTests {
    @Test func permissionIsRequestedOnlyWhenNeededAndDailyTriggerIsScheduled() async throws {
        let notifications = FakeNotifications()
        try await StudyReminder.schedule(at: ReminderTime(hour: 18, minute: 45), notifications: notifications)
        #expect(notifications.permissionRequests == 1)
        let request = try #require(notifications.added.first)
        let trigger = try #require(request.trigger as? UNCalendarNotificationTrigger)
        #expect(trigger.repeats)
        #expect(trigger.dateComponents.hour == 18)
        #expect(trigger.dateComponents.minute == 45)

        notifications.status = .authorized
        try await StudyReminder.schedule(at: ReminderTime(hour: 20, minute: 0), notifications: notifications)
        #expect(notifications.permissionRequests == 1)
        #expect(notifications.added.last?.identifier == request.identifier)
        StudyReminder.cancel(notifications: notifications)
        #expect(notifications.cancelled == [request.identifier])
    }

    @Test func deniedPermissionDoesNotScheduleAnything() async {
        let notifications = FakeNotifications()
        notifications.grantsPermission = false
        do {
            try await StudyReminder.schedule(at: ReminderTime(hour: 18, minute: 0), notifications: notifications)
            Issue.record("Denied permission must not schedule a reminder")
        } catch {
            #expect(error is StudyReminder.ReminderError)
        }
        #expect(notifications.added.isEmpty)
        notifications.status = .denied
        do {
            try await StudyReminder.schedule(at: ReminderTime(hour: 19, minute: 0), notifications: notifications)
            Issue.record("An existing denial must be reported")
        } catch {
            #expect(error is StudyReminder.ReminderError)
        }
        #expect(notifications.permissionRequests == 1)
        #expect(notifications.added.isEmpty)
    }
}
