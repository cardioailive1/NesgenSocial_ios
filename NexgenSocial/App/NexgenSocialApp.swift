import SwiftUI
import UIKit

@main
struct NexgenSocialApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var session = AuthSession()
    @StateObject private var callService = CallService.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .environmentObject(callService)
                .preferredColorScheme(.dark)
                .task { await session.restore() }
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        PushLog.write("app launched — notification delegate set, registering for VoIP pushes")
        // VoIP registration must happen at launch, not lazily: iOS only
        // delivers call pushes to an app that registered before the push
        // arrived.
        // Synchronously, not in a Task: a Task defers registration to a later
        // runloop turn, and a cold launch caused by a VoIP push delivers that
        // push before the turn arrives -- which terminates the app. This
        // delegate method already runs on the main actor.
        MainActor.assumeIsolated { CallService.shared.registerForVoIPPushes() }
        return true
    }

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        PushLog.write("didRegisterForRemoteNotifications — APNs accepted registration, \(deviceToken.count)-byte token")
        Task { @MainActor in PushService.shared.handleDeviceToken(deviceToken) }
    }

    // Background/silent deliveries never reach the UNUserNotificationCenter
    // delegate, so without this a push that arrives while the app isn't
    // foreground leaves no trace at all in the log.
    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable: Any]) async
    -> UIBackgroundFetchResult {
        PushLog.write("push received in background (state=\(application.applicationState.logName)): \(userInfo)")
        return .noData
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // The usual causes are a provisioning profile without the push
        // entitlement, or a simulator -- neither of which is visible on
        // screen, so it goes in the log.
        PushLog.write("APNs registration FAILED: \(error.localizedDescription)")
        print("APNs registration failed: \(error.localizedDescription)")
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    // Shows notifications while the app is open too -- otherwise a message
    // arriving while you're on another screen is invisible.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async
    -> UNNotificationPresentationOptions {
        PushLog.write("push received while app in foreground: \(notification.request.content.userInfo)")
        return [.banner, .sound, .badge]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        let info = response.notification.request.content.userInfo
        PushLog.write("notification tapped: \(info)")
        guard let urlString = info["url"] as? String else {
            PushLog.write("no `url` key in payload — tap routes nowhere")
            return
        }
        // Buffered as well as posted: on a cold launch this runs before any
        // view is listening, and a tapped notification that goes nowhere is
        // worse than no notification at all.
        await MainActor.run { PushService.shared.pendingDeepLink = urlString }
        NotificationCenter.default.post(name: .openDeepLink, object: urlString)
    }
}

extension Notification.Name {
    static let openDeepLink = Notification.Name("openDeepLink")
}

private extension UIApplication.State {
    var logName: String {
        switch self {
        case .active: return "active"
        case .inactive: return "inactive"
        case .background: return "background"
        @unknown default: return "unknown"
        }
    }
}
