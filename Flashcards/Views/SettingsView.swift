import SwiftUI
import UserNotifications

struct SettingsView: View {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("reminder.enabled") private var reminderEnabled = false
    @AppStorage("reminder.hour") private var reminderHour = 19
    @AppStorage("reminder.minute") private var reminderMinute = 0
    @State private var isUpdatingReminder = false
    @State private var notificationStatus = "Checking…"
    @State private var reminderError: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Daily Study Reminder", isOn: Binding(
                        get: { reminderEnabled },
                        set: { updateReminder(enabled: $0, hour: reminderHour, minute: reminderMinute) }
                    ))
                    .disabled(isUpdatingReminder)
                    if reminderEnabled {
                        DatePicker("Time", selection: Binding(
                            get: { Calendar.current.date(from: ReminderTime(hour: reminderHour, minute: reminderMinute).dateComponents) ?? .now },
                            set: { date in
                                let components = Calendar.current.dateComponents([.hour, .minute], from: date)
                                updateReminder(enabled: true, hour: components.hour ?? 19, minute: components.minute ?? 0)
                            }
                        ), displayedComponents: .hourAndMinute)
                        .disabled(isUpdatingReminder)
                    }
                    LabeledContent("Notifications", value: notificationStatus)
                    if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                        Link("Open iOS Settings", destination: settingsURL)
                    }
                } header: {
                    Text("Reminders")
                } footer: {
                    Text("Receive one reminder each day at your chosen local time. Notification permission is requested only when you turn this on.")
                }

                Section("About Flashies") {
                    LabeledContent("Version", value: version)
                    NavigationLink("Privacy", destination: PrivacyView())
                    NavigationLink("Help", destination: HelpView())
                    if let url = ReleaseLinks.url(for: "FlashiesSupportURL") {
                        Link("Support Website", destination: url)
                    }
                    if let url = ReleaseLinks.url(for: "FlashiesPrivacyURL") {
                        Link("Privacy Policy", destination: url)
                    }
                }
            }
            .navigationTitle("Settings")
            .task { await refreshStatus() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await refreshStatus() } }
            }
            .alert("Reminder Not Set", isPresented: .isPresent($reminderError)) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(reminderError ?? "")
            }
        }
    }

    private var version: String {
        let name = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(name) (\(build))"
    }

    private func updateReminder(enabled: Bool, hour: Int, minute: Int) {
        guard !isUpdatingReminder else { return }
        if !enabled {
            StudyReminder.cancel()
            reminderEnabled = false
            return
        }
        isUpdatingReminder = true
        Task {
            defer { isUpdatingReminder = false }
            do {
                try await StudyReminder.schedule(at: ReminderTime(hour: hour, minute: minute))
                reminderHour = hour
                reminderMinute = minute
                reminderEnabled = true
            } catch {
                reminderError = error.localizedDescription
            }
            await refreshStatus()
        }
    }

    private func refreshStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral: notificationStatus = "Allowed"
        case .denied: notificationStatus = "Disabled in iOS Settings"
        case .notDetermined: notificationStatus = "Not requested"
        @unknown default: notificationStatus = "Unknown"
        }
    }
}

enum ReleaseLinks {
    static func url(for key: String) -> URL? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
              let url = URL(string: value), url.scheme == "https", url.host != nil else { return nil }
        return url
    }
}

struct PrivacyView: View {
    var body: some View {
        List {
            Section("Your Study Data") {
                Text("Flashies stores your modules, chapters, cards, tags, favourites and review history locally on this device. Export and import chapters or modules to move your study material to another device.")
            }
            Section("No Advertising or Tracking") {
                Text("Flashies includes no advertising, third-party analytics or tracking SDKs. Your card content is not sent to an AI service or a developer-operated server.")
            }
            Section("Files and Notifications") {
                Text("Flashies reads only the files you choose to import. Exported files contain your study content and may include progress; share them only with people you choose. Study reminders are local notifications and are optional.")
            }
            Section("Your Controls") {
                Text("Export chapters or modules to keep a copy. Delete modules or cards in Library to remove them and their review history from this device. Exported copies remain wherever you saved them until you delete those files.")
            }
        }
        .navigationTitle("Privacy")
    }
}

struct HelpView: View {
    var body: some View {
        List {
            Section("Build Your Library") {
                Text("Create a module, add a chapter, then import CSV or Markdown files or write cards by hand. Edit a card to add tags and mark it as a favourite.")
            }
            Section("Study a Little Each Day") {
                Text("Review shows the cards that are due. Reveal an answer before grading it. Got It increases the time until the next review; Again brings the card back in ten minutes. Library lets you study any chapter at any time.")
            }
            Section("Back Up and Restore") {
                Text("Use Export Chapter inside a chapter or Export Module in a module’s More menu. Import chapters from the module’s + menu and modules from Library’s + menu. Imports create copies and let you keep or reset study progress.")
            }
        }
        .navigationTitle("Help")
    }
}

#if DEBUG
#Preview("Settings") { SettingsView() }
#endif
