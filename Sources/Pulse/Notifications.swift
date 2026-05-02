import Foundation
import UserNotifications

@MainActor
final class NotificationsManager {
    static let shared = NotificationsManager()
    private var authRequested = false
    private var authorized = false

    func requestAuthorizationIfNeeded() async {
        guard !authRequested else { return }
        authRequested = true
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
            authorized = granted
        } catch {
            authorized = false
        }
    }

    func notify(title: String, body: String, identifier: String = UUID().uuidString) {
        guard authorized else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let req = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req, withCompletionHandler: nil)
    }
}
