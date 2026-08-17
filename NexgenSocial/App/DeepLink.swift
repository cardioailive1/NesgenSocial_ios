import Foundation

/// Where a push notification's `url` should land.
///
/// Parsing lives here rather than inline in `RootView` because two places now
/// need it — the tab bar, and `MessagesView`, which opens the specific
/// conversation a message notification came from — and because a pure function
/// over strings is the one part of deep linking that can be tested without a
/// device.
enum DeepLink: Equatable {
    case feed
    case reels
    case discover
    case profile
    /// `conversationId` is nil for a bare `/messages` link.
    case messages(conversationId: String?)

    /// Accepts either a full URL or a bare path; anything unrecognised
    /// returns nil, and the caller leaves the user where they are.
    static func parse(_ link: String) -> DeepLink? {
        let path = URL(string: link)?.path ?? link
        let parts = path.split(separator: "/").map(String.init)
        guard let first = parts.first else { return nil }

        switch first {
        case "messages", "conversations": return .messages(conversationId: parts.dropFirst().first)
        case "reels": return .reels
        case "profile", "me": return .profile
        case "friends", "groups", "notifications": return .discover
        // A link to one post can only open the Feed tab: the backend has no
        // single-post route to fetch it with (`GET /api/posts/{id}` → 404),
        // and `PostDetailView` needs the whole post, not an id.
        case "posts", "feed": return .feed
        default: return nil
        }
    }

    /// Tab index in `MainTabView`.
    var tab: Int {
        switch self {
        case .feed: return 0
        case .reels: return 1
        case .discover: return 2
        case .messages: return 3
        case .profile: return 4
        }
    }
}
