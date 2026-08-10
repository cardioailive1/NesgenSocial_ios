import Foundation

enum CirclesService {

    static func all() async throws -> [AudienceCircle] {
        try await APIClient.shared.get(APIEndpoints.Circles.root, as: CirclesResponse.self).circles
    }

    static func create(name: String, memberUsernames: [String]) async throws -> AudienceCircle {
        try await APIClient.shared.post(APIEndpoints.Circles.root,
                                        body: ["name": name, "memberUsernames": memberUsernames],
                                        as: CircleResponse.self).circle
    }

    static func delete(_ circleId: String) async throws {
        _ = try await APIClient.shared.delete(APIEndpoints.Circles.circle(circleId))
    }

    static func addMember(_ username: String, to circleId: String) async throws {
        _ = try await APIClient.shared.post(APIEndpoints.Circles.members(circleId),
                                            body: ["username": username],
                                            as: EmptyResponse.self)
    }

    static func removeMember(_ userId: String, from circleId: String) async throws {
        _ = try await APIClient.shared.delete(APIEndpoints.Circles.member(circleId, userId: userId))
    }
}
