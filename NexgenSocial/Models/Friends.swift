import Foundation

struct FriendRequest: Codable, Identifiable {
    let id: String
    var createdAt: String?
    var sender: User?
    var receiver: User?
}

struct FriendSuggestion: Codable, Identifiable {
    let id: String
    let username: String
    var displayName: String?
    var avatarUrl: String?
    var bio: String?
    var occupation: String?
    var city: String?
    var reason: String?
    var mutuals: Int?
}

struct FriendsResponse: Codable {
    let incomingRequests: [FriendRequest]
    let sentRequests: [FriendRequest]
    let friends: [User]
}

struct SuggestionsResponse: Codable { let suggestions: [FriendSuggestion] }

/// `GET /api/suggestions/profile-status`. `isComplete` is the server's own
/// judgement: a photo, a bio and interests are enough, the rest is optional.
struct ProfileStatus: Codable {
    let completeness: Int
    let missing: [ProfileGap]
    let isComplete: Bool
}

struct ProfileGap: Codable, Identifiable {
    let key: String
    let label: String
    /// A web route (`/profile-setup`, `/people`). Kept for parity of the
    /// payload; iOS shows the label and hint instead of linking.
    var action: String?
    var hint: String?

    var id: String { key }
}
