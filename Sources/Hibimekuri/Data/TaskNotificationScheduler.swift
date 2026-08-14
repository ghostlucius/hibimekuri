import Foundation
import UserNotifications
import OSLog

/// Schedules a single, simple local reminder for a task's deadline —
/// `TaskItem.deferDate` doubles as the deadline this notifies about (see
/// that field's own doc comment for why it's one field, not two). Local
/// notifications only, no APNs/entitlement/paid-account requirement, so
/// this works fine for an ad-hoc-signed, non-App-Store build.
enum TaskNotificationScheduler {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.hibimekuri.app",
        category: "notifications"
    )

    /// Checks the existing system decision before requesting permission. The
    /// completion is always delivered on the main actor so store observers
    /// can safely reschedule from their MainActor isolation.
    static func requestAuthorization() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                notifyAuthorizationAvailable()
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound]) { granted, error in
                    if let error {
                        logger.error("Notification authorization failed: \(error.localizedDescription, privacy: .public)")
                    }
                    if granted {
                        notifyAuthorizationAvailable()
                    }
                }
            case .denied:
                break
            @unknown default:
                break
            }
        }
    }

    private static func notifyAuthorizationAvailable() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .taskNotificationAuthorizationChanged, object: nil)
        }
    }

    /// Reads directly from `UserDefaults`, like `AppearanceController`
    /// does, since this runs from `TaskStore` mutations that have no
    /// View/App context to read `@AppStorage` from.
    private static var currentLanguage: AppLanguage {
        let raw = UserDefaults.standard.string(forKey: "appLanguage") ?? AppLanguage.japanese.rawValue
        return AppLanguage(rawValue: raw) ?? .japanese
    }

    /// Replaces all open reminders from the current task snapshot. Call this
    /// on launch and after notification authorization changes, because the
    /// system's pending notification queue can be cleared independently of
    /// the app's JSON data.
    static func rescheduleAll(_ tasks: [TaskItem]) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: tasks.map { $0.id.uuidString })
        scheduleWhenAuthorized(center) {
            tasks.forEach { schedule($0, with: center) }
        }
    }

    /// Replaces any existing reminder for this task with a fresh one for
    /// 9:00 AM local on its deadline, or soon if today's 9:00 AM has already
    /// passed. Removes the reminder entirely if the task
    /// no longer has an open deadline to remind about (done, archived, or
    /// the date was cleared). Safe to call after any task mutation —
    /// always clears the old request first, so there's never a stale
    /// duplicate.
    static func reschedule(for task: TaskItem) {
        let identifier = task.id.uuidString
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        scheduleWhenAuthorized(center) {
            schedule(task, with: center)
        }
    }

    private static func scheduleWhenAuthorized(
        _ center: UNUserNotificationCenter,
        action: @escaping @Sendable () -> Void
    ) {
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else { return }
            action()
        }
    }

    private static func schedule(_ task: TaskItem, with center: UNUserNotificationCenter) {
        guard !task.isDone, task.archivedAt == nil, let deferDate = task.deferDate else { return }

        guard let fireDate = nextFireDate(for: deferDate) else { return }

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let content = UNMutableNotificationContent()
        content.title = Localizer.t("今日締め切りのタスク", "Task due today", language: currentLanguage)
        content.body = task.title
        content.sound = .default

        center.add(UNNotificationRequest(identifier: task.id.uuidString, content: content, trigger: trigger)) { error in
            if let error {
                logger.error("Couldn't schedule task reminder: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private static func nextFireDate(for deferDate: Date) -> Date? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let deadlineDay = calendar.startOfDay(for: deferDate)

        var components = calendar.dateComponents([.year, .month, .day], from: deadlineDay)
        components.hour = 9
        components.minute = 0
        guard let nineAM = calendar.date(from: components) else { return nil }

        if nineAM > Date() {
            return nineAM
        }
        if deadlineDay == today {
            return Date().addingTimeInterval(60)
        }
        return nil
    }
}
