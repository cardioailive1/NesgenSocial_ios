import Foundation

struct Reel: Codable, Identifiable {
    let id: String
    let videoUrl: String
    var thumbnailUrl: String?
    var caption: String?
    var durationSec: Double?
    var soundName: String?
    var isOriginalAudio: Bool?
    var author: User?
    var hashtags: [String]?
    var viewCount: Int?
    var likeCount: Int?
    var commentCount: Int?
    var likedByViewer: Bool?
}

struct ReelsResponse: Codable { let reels: [Reel] }
struct ReelResponse: Codable { let reel: Reel }

struct TrendingHashtag: Codable, Identifiable {
    let tag: String
    var reelCount: Int?

    var id: String { tag }
}

struct TrendingHashtagsResponse: Codable { let trending: [TrendingHashtag] }
