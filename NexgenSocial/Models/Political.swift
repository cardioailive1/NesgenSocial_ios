import Foundation

struct PoliticalPage: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    var type: String?
    var description: String?
    var organization: String?
    var websiteUrl: String?
    var region: String?
    var avatarUrl: String?
    var coverUrl: String?
    var media: [MediaItem]?
    var verified: Bool?
    var owner: User?
    var followerCount: Int?
    var postCount: Int?
    var adCount: Int?
    var followedByViewer: Bool?
}

struct PoliticalPost: Codable, Identifiable {
    let id: String
    let body: String
    var createdAt: String?
    var media: [MediaItem]?
}

/// An entry in the permanent ad archive. Ads stay here after they stop
/// running — that permanence is the point of the archive.
struct PoliticalAd: Codable, Identifiable, Hashable {
    let id: String
    var headline: String?
    var body: String?
    var imageUrl: String?
    var mediaUrl: String?
    var mediaKind: String?
    var targetUrl: String?
    var paidForBy: String?
    var spendCents: Int?
    var region: String?
    var active: Bool?
    var startedAt: String?
    var endedAt: String?
    var impressions: Int?
    var clicks: Int?
    var page: PoliticalPage?
}

struct PoliticalArchiveResponse: Codable { let ads: [PoliticalAd] }
struct PoliticalAdResponse: Codable { let ad: PoliticalAd }
struct PoliticalPageResponse: Codable { let page: PoliticalPage }
struct PoliticalPagesResponse: Codable { let pages: [PoliticalPage] }
struct PoliticalPostsResponse: Codable { let posts: [PoliticalPost] }
