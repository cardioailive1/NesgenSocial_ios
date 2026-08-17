import Foundation

/// Device-token registration, kept with the other services rather than inline
/// in `PushService` and `CallService` — G8 in `FEATURE_AUDIT.md`.
///
/// Both token kinds carry the same device identity. It is built once here
/// because getting it wrong is invisible: a missing `environment` makes the
/// server push to the wrong APNs host and the notification simply never
/// arrives.
enum PushSubscriptionService {

    static func subscribeAPNs(deviceToken: String) async throws {
        _ = try await APIClient.shared.post(
            APIEndpoints.Push.apnsSubscribe,
            body: device(["deviceToken": deviceToken]),
            as: EmptyResponse.self
        )
    }

    static func unsubscribeAPNs(deviceToken: String) async throws {
        _ = try await APIClient.shared.post(
            APIEndpoints.Push.apnsUnsubscribe,
            body: ["deviceToken": deviceToken],
            as: EmptyResponse.self
        )
    }

    static func subscribeVoIP(token: String) async throws {
        _ = try await APIClient.shared.post(
            APIEndpoints.Push.voipSubscribe,
            body: device(["voipToken": token]),
            as: EmptyResponse.self
        )
    }

    private static func device(_ token: [String: Any]) -> [String: Any] {
        token.merging([
            "platform": "ios",
            "bundleId": Bundle.main.bundleIdentifier ?? "",
            "environment": AppEnvironment.isDebugBuild ? "sandbox" : "production",
        ]) { current, _ in current }
    }
}
