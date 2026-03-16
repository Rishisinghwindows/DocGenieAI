import Foundation
@preconcurrency import UserNotifications

final class ExpiryNotificationService: Sendable {
    static let shared = ExpiryNotificationService()

    private nonisolated(unsafe) let center = UNUserNotificationCenter.current()

    private init() {}

    func requestPermission() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            return false
        }
    }

    func scheduleReminder(for file: DocumentFile) {
        guard let expiryDate = file.expiryDate else { return }

        let reminderDays = file.expiryReminderDays ?? 30
        guard let reminderDate = Calendar.current.date(byAdding: .day, value: -reminderDays, to: expiryDate) else { return }

        // Don't schedule if the reminder date is already past
        guard reminderDate > Date.now else { return }

        let content = UNMutableNotificationContent()
        content.title = "Document Expiring Soon"
        if let note = file.expiryNote, !note.isEmpty {
            content.body = "\(note) - \"\(file.fullFileName)\" expires in \(reminderDays) days."
        } else {
            content.body = "\"\(file.fullFileName)\" expires in \(reminderDays) days."
        }
        content.sound = .default

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminderDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(
            identifier: file.id.uuidString,
            content: content,
            trigger: trigger
        )

        center.add(request)
    }

    func cancelReminder(for file: DocumentFile) {
        center.removePendingNotificationRequests(withIdentifiers: [file.id.uuidString])
    }
}
