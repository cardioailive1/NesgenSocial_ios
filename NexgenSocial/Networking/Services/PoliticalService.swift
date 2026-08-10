import Foundation

enum PoliticalService {

    static func pages(type: String) async throws -> [PoliticalPage] {
        let path = type.isEmpty
            ? APIEndpoints.Political.pages
            : "\(APIEndpoints.Political.pages)?type=\(type.urlQueryEscaped)"
        return try await APIClient.shared.get(path, as: PoliticalPagesResponse.self).pages
    }

    static func posts(on pageId: String) async throws -> [PoliticalPost] {
        try await APIClient.shared
            .get(APIEndpoints.Political.posts(pageId), as: PoliticalPostsResponse.self).posts
    }

    static func setFollowing(_ following: Bool, pageId: String) async throws {
        if following {
            _ = try await APIClient.shared.post(APIEndpoints.Political.follow(pageId),
                                                as: EmptyResponse.self)
        } else {
            _ = try await APIClient.shared.delete(APIEndpoints.Political.follow(pageId))
        }
    }
}
