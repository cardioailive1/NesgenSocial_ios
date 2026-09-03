import Foundation

/// The friend graph: requests in both directions, the accepted list, and
/// suggestions.
enum FriendsService {

    static func overview() async throws -> FriendsResponse {
        try await APIClient.shared.get(APIEndpoints.Friends.root, as: FriendsResponse.self)
    }

    static func friends() async throws -> [User] {
        try await overview().friends
    }

    static func suggestions() async throws -> [FriendSuggestion] {
        try await APIClient.shared
            .get(APIEndpoints.Friends.suggestions, as: SuggestionsResponse.self).suggestions
    }

    /// How far along this account's profile is, and what is still missing.
    static func profileStatus() async throws -> ProfileStatus {
        try await APIClient.shared.get(APIEndpoints.Friends.profileStatus, as: ProfileStatus.self)
    }

    static func sendRequest(to username: String) async throws {
        _ = try await APIClient.shared.post(APIEndpoints.Friends.requests,
                                            body: ["username": username],
                                            as: EmptyResponse.self)
    }

    static func respond(to requestId: String, accept: Bool) async throws {
        _ = try await APIClient.shared.patch(APIEndpoints.Friends.request(requestId),
                                             body: ["action": accept ? "accept" : "decline"],
                                             as: EmptyResponse.self)
    }

    static func cancelRequest(_ requestId: String) async throws {
        _ = try await APIClient.shared.delete(APIEndpoints.Friends.request(requestId))
    }

    static func remove(_ friendId: String) async throws {
        _ = try await APIClient.shared.delete(APIEndpoints.Friends.friend(friendId))
    }
}
