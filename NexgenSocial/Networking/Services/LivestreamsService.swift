import Foundation

enum LivestreamsService {

    static func all() async throws -> [Livestream] {
        try await APIClient.shared
            .get(APIEndpoints.Livestreams.root, as: LivestreamsResponse.self).streams
    }

    static func start(title: String) async throws -> Livestream {
        try await APIClient.shared.post(APIEndpoints.Livestreams.root,
                                        body: ["title": title],
                                        as: LivestreamResponse.self).stream
    }

    static func end(_ streamId: String) async throws {
        _ = try await APIClient.shared.post(APIEndpoints.Livestreams.end(streamId),
                                            as: LivestreamResponse.self)
    }
}
