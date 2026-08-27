import Foundation
import UserNotifications

/// In-app notification list.
///
/// ponytail: reads iOS's own delivered-notification store rather than keeping
/// a local copy, so there is nothing to persist, migrate or reconcile. The
/// ceiling is that the list only holds what is still sitting in Notification
/// Center — clearing it there clears it here, and pushes that arrived while
/// the app was foregrounded and dismissed are gone. Swap `load()` for
/// `GET /api/notifications` once the backend has a feed endpoint (none exists
/// today, see FEATURE_AUDIT.md).
@MainActor
final class NotificationsViewModel: ObservableObject {
    @Published var items: [UNNotification] = []
    @Published var permissionGranted = true

    func load() async {
        let center = UNUserNotificationCenter.current()
        // Matches PushService: provisional and ephemeral deliver too, so
        // treating them as denied would show a "turn on notifications"
        // prompt to someone already receiving them.
        permissionGranted = await PushService.shared.isAuthorized
        items = await center.deliveredNotifications().sorted { $0.date > $1.date }
    }

    func requestPermission() async {
        permissionGranted = await PushService.shared.requestPermission()
    }

    /// Opening consumes the notification: it routes through the same deep-link
    /// path the tap-from-lock-screen handler uses, then drops it so the badge
    /// and the list agree.
    func open(_ note: UNNotification) {
        remove(note)
        if let url = note.request.content.userInfo["url"] as? String {
            NotificationCenter.default.post(name: .openDeepLink, object: url)
        }
    }

    func remove(_ note: UNNotification) {
        UNUserNotificationCenter.current()
            .removeDeliveredNotifications(withIdentifiers: [note.request.identifier])
        items.removeAll { $0.request.identifier == note.request.identifier }
    }

    func clearAll() {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        items.removeAll()
    }
}
