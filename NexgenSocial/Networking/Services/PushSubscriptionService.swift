import Foundation

/// Device-token registration, kept with the other services rather than inline
/// in `PushService` and `CallService` — G8 in `FEATURE_AUDIT.md`.
///
/// Both token kinds carry the same device identity. It is built once here
/// because getting it wrong is invisible: a missing `environment` makes the
/// server push to the wrong APNs host and the notification simply never
/// arrives.
///
/// Tokens are also cached locally, because iOS hands them over at launch —
/// before anyone has signed in — and the subscribe call needs a bearer token.
/// Without the cache that first registration 401s and is never retried, so a
/// freshly installed app silently never receives a push. `syncPendingTokens()`
/// replays them once a session exists; the server upserts on (token, kind),
/// so replaying is free.
enum PushSubscriptionService {

    private static let defaults = UserDefaults.standard
    private static let apnsKey = "push.apnsDeviceToken"
    private static let voipKey = "push.voipDeviceToken"

    static func subscribeAPNs(deviceToken: String) async throws {
        defaults.set(deviceToken, forKey: apnsKey)
        try await send(APIEndpoints.Push.apnsSubscribe, device(["deviceToken": deviceToken]))
    }

    static func unsubscribeAPNs(deviceToken: String) async throws {
        try await send(APIEndpoints.Push.apnsUnsubscribe, ["deviceToken": deviceToken])
    }

    static func subscribeVoIP(token: String) async throws {
        defaults.set(token, forKey: voipKey)
        try await send(APIEndpoints.Push.voipSubscribe, device(["voipToken": token]))
    }

    static func unsubscribeVoIP(token: String) async throws {
        try await send(APIEndpoints.Push.voipUnsubscribe, ["voipToken": token])
    }

    /// Every registration call goes through here so each one is logged the
    /// same way. `postRaw` is used rather than `post` because a failure needs
    /// the status code and the server's own words, not a display string.
    private static func send(_ endpoint: String, _ body: [String: Any]) async throws {
        do {
            let (status, response) = try await APIClient.shared.postRaw(endpoint, body: body)
            PushLog.request(endpoint, body: body, status: status, response: response)
            guard (200..<300).contains(status) else {
                throw APIError.server("\(endpoint) failed (\(status)): \(response)")
            }
        } catch let error as APIError {
            throw error
        } catch {
            // Transport failure -- no status code exists to report.
            PushLog.failure(endpoint, body: body, error: error)
            throw error
        }
    }

    /// Re-sends whatever tokens this device already has. Call after sign-in.
    static func syncPendingTokens() async {
        let apns = defaults.string(forKey: apnsKey)
        let voip = defaults.string(forKey: voipKey)
        PushLog.write("replaying cached tokens — apns: \(apns ?? "none"), voip: \(voip ?? "none")")
        if let apns { try? await subscribeAPNs(deviceToken: apns) }
        if let voip { try? await subscribeVoIP(token: voip) }
    }

    /// Detaches this device from the account being signed out of, so the next
    /// person to sign in on it doesn't get the previous one's notifications.
    /// The cached tokens are kept: the device token itself hasn't changed, and
    /// the next sign-in re-registers it against the new account.
    static func unsubscribeAll() async {
        if let token = defaults.string(forKey: apnsKey) {
            try? await unsubscribeAPNs(deviceToken: token)
        }
        if let token = defaults.string(forKey: voipKey) {
            try? await unsubscribeVoIP(token: token)
        }
    }

    private static func device(_ token: [String: Any]) -> [String: Any] {
        token.merging([
            "platform": "ios",
            "bundleId": Bundle.main.bundleIdentifier ?? "",
            "environment": AppEnvironment.isDebugBuild ? "sandbox" : "production",
        ]) { current, _ in current }
    }
}
