import Foundation

enum NewsService {

    static func breaking() async throws -> BreakingNewsResponse {
        try await APIClient.shared.get(APIEndpoints.News.breaking, as: BreakingNewsResponse.self)
    }

    static func newsrooms() async throws -> [Newsroom] {
        try await APIClient.shared
            .get(APIEndpoints.News.newsrooms, as: NewsroomsResponse.self).newsrooms
    }

    static func newsroom(slug: String) async throws -> Newsroom {
        try await APIClient.shared
            .get(APIEndpoints.News.newsroom(slug), as: NewsroomResponse.self).newsroom
    }

    static func setFollowing(_ following: Bool, newsroomId: String) async throws {
        if following {
            _ = try await APIClient.shared.post(APIEndpoints.News.follow(newsroomId),
                                                as: EmptyResponse.self)
        } else {
            _ = try await APIClient.shared.delete(APIEndpoints.News.follow(newsroomId))
        }
    }
}
