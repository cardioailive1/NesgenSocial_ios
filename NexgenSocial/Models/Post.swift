import Foundation

struct Post: Codable, Identifiable {
    let id: String
    let body: String?
    var type: String?
    var mediaUrl: String?
    var media: [MediaItem]?
    var createdAt: String?
    var author: User?
    var likeCount: Int?
    var commentCount: Int?
    var likedByViewer: Bool?
    var audience: String?
    var category: String?
    /// Server sends this as `feedReason` ("Followed by …", "Trending in …").
    var feedReason: String?

    // Older posts predate the media array and only carry mediaUrl. Falling
    // back here keeps them rendering instead of showing an empty card.
    var displayMedia: [MediaItem] {
        if let media, !media.isEmpty { return media }
        guard let mediaUrl, !mediaUrl.isEmpty else { return [] }
        let inferred: MediaAssetKind = type == "VIDEO"
            ? .video
            : (mediaUrl.lowercased().hasSuffix(".webm")
               || mediaUrl.lowercased().hasSuffix(".mp4")
               || mediaUrl.lowercased().hasSuffix(".mov") ? .video : .photo)
        return [MediaItem(id: "legacy-\(id)", url: mediaUrl, kind: inferred, position: 0, caption: nil)]
    }
}

/// Identity is the id alone, which is what `navigationDestination(item:)`
/// needs. Comparing every field would make a like-count refresh look like a
/// different post and re-push the detail screen.
extension Post: Hashable {
    static func == (lhs: Post, rhs: Post) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - Comments and context notes

struct Comment: Codable, Identifiable {
    let id: String
    let body: String
    var createdAt: String?
    var author: User?
}

/// Crowd-sourced context on a post, with its helpful/not-helpful tally.
struct ContextNote: Codable, Identifiable {
    let id: String
    let body: String
    var createdAt: String?
    var author: User?
    var helpfulCount: Int?
    var notHelpfulCount: Int?
    var viewerVote: Int?
}

struct FeedResponse: Codable { let posts: [Post] }
struct CommentsResponse: Codable { let comments: [Comment] }
struct CommentResponse: Codable { let comment: Comment }
struct ContextNotesResponse: Codable { let notes: [ContextNote] }
