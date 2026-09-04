import Foundation

/// People, jobs, and marketplace search — the three things the Explore screen
/// queries with the same search term.
enum DiscoveryService {

    static func users(matching query: String) async throws -> [User] {
        try await APIClient.shared.get(APIEndpoints.Users.search(query), as: UsersResponse.self).users
    }

    /// Everyone on the platform, each row carrying the viewer's relationship
    /// to that person (`isFollowing`, `friendStatus`) so the People screen can
    /// pick the right buttons without a request per row.
    static func people(matching query: String) async throws -> [User] {
        try await APIClient.shared.get(APIEndpoints.Users.search(query), as: UsersResponse.self).users
    }

    static func jobs(matching query: String) async throws -> [JobPosting] {
        try await APIClient.shared.get(APIEndpoints.Jobs.search(query), as: JobsResponse.self).jobs
    }

    static func listings(matching query: String) async throws -> [MarketListing] {
        try await APIClient.shared
            .get(APIEndpoints.Marketplace.listings(query: query), as: ListingsResponse.self).listings
    }

    /// Who follows `username`, and who they follow back. Both routes are
    /// public -- they carry no viewer relationship fields, so rows here get
    /// a name and an avatar and nothing else.
    static func followers(of username: String) async throws -> [User] {
        try await APIClient.shared
            .get(APIEndpoints.Follows.followers(username), as: FollowersResponse.self).followers
    }

    static func following(of username: String) async throws -> [User] {
        try await APIClient.shared
            .get(APIEndpoints.Follows.following(username), as: FollowingResponse.self).following
    }

    static func setFollowing(_ following: Bool, username: String) async throws {
        if following {
            _ = try await APIClient.shared.post(APIEndpoints.Follows.user(username), as: EmptyResponse.self)
        } else {
            _ = try await APIClient.shared.delete(APIEndpoints.Follows.user(username))
        }
    }
}
