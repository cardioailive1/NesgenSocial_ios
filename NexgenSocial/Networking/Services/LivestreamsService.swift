import Foundation

enum LivestreamsService {

    static func all() async throws -> [Livestream] {
        try await APIClient.shared
            .get(APIEndpoints.Livestreams.root, as: LivestreamsResponse.self).streams
    }

    /// One stream, including its `status`. The list only returns LIVE ones,
    /// so this is the only way to learn a stream you are watching has ended.
    static func detail(_ streamId: String) async throws -> Livestream {
        try await APIClient.shared
            .get(APIEndpoints.Livestreams.detail(streamId), as: LivestreamResponse.self).stream
    }

    /// `newsroomId` broadcasts under a newsroom's name. The server only
    /// honours it for a newsroom you own.
    static func start(title: String, newsroomId: String? = nil) async throws -> Livestream {
        var body: [String: Any] = ["title": title]
        if let newsroomId { body["newsroomId"] = newsroomId }
        return try await APIClient.shared.post(APIEndpoints.Livestreams.root,
                                               body: body,
                                               as: LivestreamResponse.self).stream
    }

    static func end(_ streamId: String) async throws {
        _ = try await APIClient.shared.post(APIEndpoints.Livestreams.end(streamId),
                                            as: LivestreamResponse.self)
    }
}
