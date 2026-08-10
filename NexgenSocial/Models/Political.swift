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

struct PoliticalPagesResponse: Codable { let pages: [PoliticalPage] }
struct PoliticalPostsResponse: Codable { let posts: [PoliticalPost] }
