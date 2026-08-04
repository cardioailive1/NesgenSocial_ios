import Foundation

// MARK: - Core models
//
// Field names mirror the JSON the NexgenSocial API returns, so no custom
// CodingKeys are needed. Optionals are used generously and deliberately:
// the API omits fields depending on the endpoint and the viewer's
// permissions, and a non-optional here means a decode failure that blanks
// an entire screen rather than one missing value.

struct User: Codable, Identifiable, Hashable {
    let id: String
    let username: String
    let displayName: String
    var avatarUrl: String?
    var bio: String?
    var occupation: String?
    var city: String?
    var country: String?
    var followerCount: Int?
    var followingCount: Int?
}

struct AuthResponse: Codable {
    let token: String
    let user: User
}

enum MediaKind: String, Codable {
    case photo = "PHOTO"
    case video = "VIDEO"
}

struct MediaItem: Codable, Identifiable, Hashable {
    let id: String
    let url: String
    let kind: MediaKind
    var position: Int?
    var caption: String?
}

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
    var reason: String?

    // Older posts predate the media array and only carry mediaUrl. Falling
    // back here keeps them rendering instead of showing an empty card.
    var displayMedia: [MediaItem] {
        if let media, !media.isEmpty { return media }
        guard let mediaUrl, !mediaUrl.isEmpty else { return [] }
        let inferred: MediaKind = type == "VIDEO"
            ? .video
            : (mediaUrl.lowercased().hasSuffix(".webm")
               || mediaUrl.lowercased().hasSuffix(".mp4")
               || mediaUrl.lowercased().hasSuffix(".mov") ? .video : .photo)
        return [MediaItem(id: "legacy-\(id)", url: mediaUrl, kind: inferred, position: 0, caption: nil)]
    }
}

struct FeedResponse: Codable {
    let posts: [Post]
}

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

// MARK: - Messaging

struct Conversation: Codable, Identifiable {
    let id: String
    var otherUser: User?
    var lastMessage: Message?
    var lastMessageAt: String?
    var unreadCount: Int?
}

struct Message: Codable, Identifiable {
    let id: String
    var body: String?
    var createdAt: String?
    var sender: User?
    var attachments: [MediaItem]?
}

struct Call: Codable, Identifiable {
    let id: String
    let callerId: String
    let calleeId: String
    let kind: String
    var status: String
    var caller: User?
    var callee: User?
    var startedAt: String?
}

// MARK: - Groups, jobs, marketplace

struct Group: Codable, Identifiable {
    let id: String
    let name: String
    var description: String?
    var owner: User?
    var memberCount: Int?
}

struct JobPosting: Codable, Identifiable {
    let id: String
    let title: String
    let companyName: String
    var description: String?
    var location: String?
    var arrangement: String?
    var employmentType: String?
    var salaryMin: Int?
    var salaryMax: Int?
    var salaryCurrency: String?
    var salaryPeriod: String?
    var appliedByViewer: Bool?
    var createdAt: String?

    var salaryText: String? {
        guard salaryMin != nil || salaryMax != nil else { return nil }
        let cur = salaryCurrency ?? "USD"
        let per = ["YEAR": "/yr", "MONTH": "/mo", "HOUR": "/hr"][salaryPeriod ?? "YEAR"] ?? ""
        let fmt: (Int) -> String = { NumberFormatter.localizedString(from: NSNumber(value: $0), number: .decimal) }
        if let lo = salaryMin, let hi = salaryMax { return "\(cur) \(fmt(lo))–\(fmt(hi))\(per)" }
        return "\(cur) \(fmt(salaryMin ?? salaryMax ?? 0))\(per)"
    }
}

struct MarketListing: Codable, Identifiable {
    let id: String
    let title: String
    let description: String
    let priceCents: Int
    var condition: String?
    var location: String?
    var seller: User?
    var media: [MediaItem]?
    var coverUrl: String?

    var priceText: String {
        String(format: "$%.2f", Double(priceCents) / 100.0)
    }
}

// MARK: - Generic envelopes

struct APIMessage: Codable { let error: String? }
struct UsersResponse: Codable { let users: [User] }
struct ConversationsResponse: Codable { let conversations: [Conversation] }
struct MessagesResponse: Codable { let messages: [Message] }
struct GroupsResponse: Codable { let groups: [Group] }
struct JobsResponse: Codable { let jobs: [JobPosting] }
struct ListingsResponse: Codable { let listings: [MarketListing] }
struct IncomingCallResponse: Codable { let call: Call? }
struct CallResponse: Codable { let call: Call }
