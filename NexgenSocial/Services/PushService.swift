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

    /// A notification tapped from the lock screen while the app was not
    /// running is delivered before any view exists to route it, so it waits
    /// here until `MainTabView` drains it.
    var pendingDeepLink: String?

    private override init() { super.init() }

    func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            permissionGranted = granted
            PushLog.write("authorization prompt returned granted=\(granted)")
            if granted {
                UIApplication.shared.registerForRemoteNotifications()
            }
            return granted
        } catch {
            PushLog.write("authorization prompt threw: \(error.localizedDescription)")
            return false
        }
    }

    /// Called once a session exists. Asks the first time, re-registers on
    /// every later launch so the server always has a current token — APNs
    /// tokens rotate on reinstall and restore, and a stale one silently drops
    /// notifications — and replays any token that arrived before sign-in.
    func registerIfAuthorized() async {
        PushLog.header()
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        PushLog.write("authorizationStatus=\(status.logName)")
        switch status {
        case .notDetermined:
            _ = await requestPermission()
        case .authorized, .provisional, .ephemeral:
            permissionGranted = true
            UIApplication.shared.registerForRemoteNotifications()
        default:
            permissionGranted = false
            PushLog.write("not authorized — no APNs token will be issued")
        }
        await PushSubscriptionService.syncPendingTokens()
    }

    /// The live authorization state, straight from iOS. `permissionGranted`
    /// is a cached mirror for views that can't await; this is the truth, and
    /// the only thing that survives the person changing it in Settings.
    var isAuthorized: Bool {
        get async {
            switch await UNUserNotificationCenter.current().notificationSettings().authorizationStatus {
            case .authorized, .provisional, .ephemeral: return true
            default: return false
            }
        }
    }

    /// iOS shows the permission prompt exactly once. After that, asking again
    /// returns the previous answer without showing anything, so a UI that
    /// offers to turn notifications on has to send people to Settings instead.
    var canStillAsk: Bool {
        get async {
            await UNUserNotificationCenter.current()
                .notificationSettings().authorizationStatus == .notDetermined
        }
    }

    static func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    func handleDeviceToken(_ token: Data) {
        let hex = token.map { String(format: "%02x", $0) }.joined()
        PushLog.write("APNs device token received (\(hex.count / 2) bytes): \(hex)")
        // Fails quietly: an unreachable server shouldn't produce an error
        // dialog on launch, and the token is cached either way, so sign-in
        // and the next launch both retry it.
        Task { try? await PushSubscriptionService.subscribeAPNs(deviceToken: hex) }
    }

    func unregister() async {
        PushLog.write("signing out — detaching this device from the account")
        await PushSubscriptionService.unsubscribeAll()
        clearBadge()
    }

    /// The badge counts what you haven't seen; opening the app is seeing it.
    func clearBadge() {
        UNUserNotificationCenter.current().setBadgeCount(0)
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


private extension UNAuthorizationStatus {
    /// `description` on this enum prints a raw integer, which is useless in
    /// a log someone has to read.
    var logName: String {
        switch self {
        case .notDetermined: return "notDetermined (never asked)"
        case .denied:        return "denied"
        case .authorized:    return "authorized"
        case .provisional:   return "provisional"
        case .ephemeral:     return "ephemeral"
        @unknown default:    return "unknown(\(rawValue))"
        }
    }
}
