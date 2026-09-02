import Foundation

/// Call signalling. The media path is WebRTCManager's job; this is only the
/// REST side that creates, polls, and transitions a call record.
enum CallsService {

    static func start(with username: String, video: Bool) async throws -> Call {
        try await APIClient.shared.post(APIEndpoints.Calls.root,
                                        body: ["username": username,
                                               "kind": video ? "VIDEO" : "AUDIO"],
                                        as: CallResponse.self).call
    }

    /// Polled. `maxAge: 0` throughout this file's live routes -- a cached
    /// answer here would mean a missed call or a call screen that never ends.
    static func incoming() async throws -> Call? {
        try await APIClient.shared.get(APIEndpoints.Calls.incoming,
                                       as: IncomingCallResponse.self, maxAge: 0).call
    }

    /// Both sides of every call, newest first (the server caps it at 50).
    static func history() async throws -> [Call] {
        try await APIClient.shared.get(APIEndpoints.Calls.history, as: CallsResponse.self).calls
    }

    static func details(_ callId: String) async throws -> Call {
        try await APIClient.shared.get(APIEndpoints.Calls.details(callId),
                                       as: CallResponse.self, maxAge: 0).call
    }

    static func setStatus(_ status: String, callId: String) async throws {
        _ = try await APIClient.shared.patch(APIEndpoints.Calls.call(callId),
                                             body: ["status": status],
                                             as: CallResponse.self)
    }
}
