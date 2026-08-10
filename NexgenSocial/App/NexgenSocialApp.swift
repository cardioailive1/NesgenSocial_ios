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
        // VoIP registration must happen at launch, not lazily: iOS only
        // delivers call pushes to an app that registered before the push
        // arrived.
        Task { @MainActor in CallService.shared.registerForVoIPPushes() }
        return true
    }

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Task { @MainActor in PushService.shared.handleDeviceToken(deviceToken) }
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("APNs registration failed: \(error.localizedDescription)")
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    // Shows notifications while the app is open too -- otherwise a message
    // arriving while you're on another screen is invisible.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async
    -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        let info = response.notification.request.content.userInfo
        if let urlString = info["url"] as? String {
            NotificationCenter.default.post(name: .openDeepLink, object: urlString)
        }
    }
}

extension Notification.Name {
    static let openDeepLink = Notification.Name("openDeepLink")
}
