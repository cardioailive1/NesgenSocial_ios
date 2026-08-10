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
