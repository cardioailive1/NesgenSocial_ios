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

    /// Every newsroom's stories in one list — the Coverage section.
    static func latestArticles() async throws -> [NewsArticle] {
        try await APIClient.shared.get(APIEndpoints.News.latestArticles,
                                       as: NewsArticlesResponse.self).articles
    }

    static func createNewsroom(fields: [String: String],
                               logo: PickedAttachment?,
                               cover: PickedAttachment?,
                               media: [PickedAttachment]) async throws -> Newsroom {
        var files = media.uploadFiles
        // The server reads the logo and the cover from their own fields;
        // sent as `media` they would become gallery items instead.
        if let logo {
            files.append((name: "avatar", filename: logo.filename,
                          mimeType: logo.mimeType, data: logo.data))
        }
        if let cover {
            files.append((name: "cover", filename: cover.filename,
                          mimeType: cover.mimeType, data: cover.data))
        }
        return try await APIClient.shared.upload(APIEndpoints.News.newsrooms,
                                                 fields: fields.filter { !$0.value.isEmpty },
                                                 files: files,
                                                 as: NewsroomResponse.self).newsroom
    }

    static func publishArticle(in newsroomId: String,
                               headline: String,
                               standfirst: String,
                               body: String,
                               byline: String,
                               isBreaking: Bool,
                               media: [PickedAttachment]) async throws -> NewsArticle {
        var fields = ["headline": headline, "body": body, "isBreaking": String(isBreaking)]
        if !standfirst.isEmpty { fields["standfirst"] = standfirst }
        if !byline.isEmpty { fields["byline"] = byline }
        return try await APIClient.shared.upload(APIEndpoints.News.articles(newsroomId),
                                                 fields: fields,
                                                 files: media.uploadFiles,
                                                 as: NewsArticleResponse.self).article
    }
}
