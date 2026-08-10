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

    static func incoming() async throws -> Call? {
        try await APIClient.shared.get(APIEndpoints.Calls.incoming, as: IncomingCallResponse.self).call
    }

    static func details(_ callId: String) async throws -> Call {
        try await APIClient.shared.get(APIEndpoints.Calls.details(callId), as: CallResponse.self).call
    }

    static func setStatus(_ status: String, callId: String) async throws {
        _ = try await APIClient.shared.patch(APIEndpoints.Calls.call(callId),
                                             body: ["status": status],
                                             as: CallResponse.self)
    }
}
