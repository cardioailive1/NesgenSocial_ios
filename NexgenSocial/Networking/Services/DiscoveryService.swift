import Foundation

/// People, jobs, and marketplace search — the three things the Explore screen
/// queries with the same search term.
enum DiscoveryService {

    static func users(matching query: String) async throws -> [User] {
        try await APIClient.shared.get(APIEndpoints.Users.search(query), as: UsersResponse.self).users
    }

    static func jobs(matching query: String) async throws -> [JobPosting] {
        try await APIClient.shared.get(APIEndpoints.Jobs.search(query), as: JobsResponse.self).jobs
    }

    static func listings(matching query: String) async throws -> [MarketListing] {
        try await APIClient.shared
            .get(APIEndpoints.Marketplace.listings(query: query), as: ListingsResponse.self).listings
    }

    static func setFollowing(_ following: Bool, username: String) async throws {
        if following {
            _ = try await APIClient.shared.post(APIEndpoints.Follows.user(username), as: EmptyResponse.self)
        } else {
            _ = try await APIClient.shared.delete(APIEndpoints.Follows.user(username))
        }
    }
}
