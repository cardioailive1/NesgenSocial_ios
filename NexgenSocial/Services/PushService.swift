import Foundation
import UIKit
import UserNotifications

/// APNs registration and permission handling.
///
/// Native push differs from the web version in the way that matters most
/// here: APNs can wake the app even when it has been terminated, which is
/// what makes real call notifications possible at all.
@MainActor
final class PushService: NSObject, ObservableObject {
    static let shared = PushService()

    @Published var permissionGranted = false
    private var deviceToken: String?

    private override init() { super.init() }

    func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            permissionGranted = granted
            if granted {
                UIApplication.shared.registerForRemoteNotifications()
            }
            return granted
        } catch {
            return false
        }
    }

    /// Re-registers on launch if the person already granted permission, so
    /// the server always has a current token. APNs tokens rotate on
    /// reinstall and restore, and a stale one silently drops notifications.
    func registerIfAuthorized() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        guard settings.authorizationStatus == .authorized else { return }
        permissionGranted = true
        UIApplication.shared.registerForRemoteNotifications()
    }

    func handleDeviceToken(_ token: Data) {
        let hex = token.map { String(format: "%02x", $0) }.joined()
        deviceToken = hex
        Task { await sendTokenToServer(hex) }
    }

    private func sendTokenToServer(_ token: String) async {
        // Fails quietly: an unreachable server shouldn't produce an error
        // dialog on launch. It re-registers next time the app opens.
        _ = try? await APIClient.shared.post(
            "/api/push/apns-subscribe",
            body: [
                "deviceToken": token,
                "platform": "ios",
                "bundleId": Bundle.main.bundleIdentifier ?? "",
                "environment": AppEnvironment.isDebugBuild ? "sandbox" : "production",
            ],
            as: EmptyResponse.self
        )
    }

    func unregister() async {
        guard let deviceToken else { return }
        _ = try? await APIClient.shared.post(
            "/api/push/apns-unsubscribe",
            body: ["deviceToken": deviceToken],
            as: EmptyResponse.self
        )
        self.deviceToken = nil
    }
}

enum AppEnvironment {
    /// APNs uses different gateways for development and App Store builds;
    /// the server needs to know which one a token belongs to or pushes
    /// silently fail to deliver.
    static var isDebugBuild: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
}
