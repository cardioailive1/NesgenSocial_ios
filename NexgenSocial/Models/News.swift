import Foundation

// MARK: - Syndicated RSS

struct NewsItem: Codable, Identifiable {
    let source: String
    let title: String
    let link: String
    var description: String?
    var publishedAt: String?

    // The feed carries no stable id, and the link is unique per story.
    var id: String { link }
}

struct BreakingNewsResponse: Codable {
    let items: [NewsItem]
    var failedSources: [String]?
    var cachedAt: String?
}

// MARK: - Newsrooms

struct Newsroom: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let slug: String
    var description: String?
    var organization: String?
    var websiteUrl: String?
    var avatarUrl: String?
    var coverUrl: String?
    var beat: String?
    var region: String?
    var verified: Bool?
    var owner: User?
    var articleCount: Int?
    var followerCount: Int?
    var followedByViewer: Bool?
    var articles: [NewsArticle]?
}

struct NewsroomRef: Codable, Hashable {
    let id: String
    let name: String
    var slug: String?
    var verified: Bool?
}

struct NewsArticle: Codable, Identifiable, Hashable {
    let id: String
    let headline: String
    var standfirst: String?
    var body: String?
    var byline: String?
    var isBreaking: Bool?
    var publishedAt: String?
    var media: [MediaItem]?
}

struct NewsroomsResponse: Codable { let newsrooms: [Newsroom] }
struct NewsroomResponse: Codable { let newsroom: Newsroom }
