import Foundation

// MARK: - Core conventions
//
// Field names across every model file mirror the JSON the NexgenSocial API
// returns, so no custom CodingKeys are needed. Optionals are used generously
// and deliberately: the API omits fields depending on the endpoint and the
// viewer's permissions, and a non-optional here means a decode failure that
// blanks an entire screen rather than one missing value.

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

    // Only `/api/users` fills these in: the viewer's relationship to this
    // person, so a list row can show the right buttons without a request per
    // row. "NONE" | "PENDING" | "ACCEPTED" | "DECLINED".
    var isFollowing: Bool?
    var friendStatus: String?
    var friendRequestIncoming: Bool?
    var friendRequestId: String?
}

struct AuthResponse: Codable {
    let token: String
    let user: User
}

// MARK: - Extended profile

struct Interest: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let category: String?
}

struct ExtendedProfile: Codable {
    let id: String
    let username: String
    var displayName: String?
    var avatarUrl: String?
    var bio: String?
    var birthDate: String?
    var gender: String?
    var relationshipStatus: String?
    var occupation: String?
    var education: String?
    var city: String?
    var country: String?
    var timezone: String?
    var hasChildren: Bool?
    var interests: [Interest]?
}

struct PrivacySettings: Codable {
    var allowInterestTargeting: Bool?
    var allowBehavioralTracking: Bool?
    var allowAggregateInsights: Bool?
    var showVisitedPlaces: Bool?
}

struct MeResponse: Codable { let user: User }
struct UsersResponse: Codable { let users: [User] }
struct FollowersResponse: Codable { let followers: [User] }
struct FollowingResponse: Codable { let following: [User] }
struct ProfileMeResponse: Codable {
    let profile: ExtendedProfile
    let privacySettings: PrivacySettings?
}
struct ProfileResponse: Codable { let profile: ExtendedProfile }
struct PrivacyResponse: Codable { let privacySettings: PrivacySettings }
struct InterestsResponse: Codable { let interests: [Interest] }

/// `GET /api/users/:username` -- the public profile with its counts. The
/// counts live outside `user` because they're computed per request rather
/// than stored on the row.
struct ProfileStats: Codable {
    var followerCount: Int?
    var followingCount: Int?
    var friendCount: Int?
}

struct ViewerContext: Codable {
    var isFollowing: Bool?
    var friendStatus: String?
}

struct UserProfileResponse: Codable {
    let user: User
    var stats: ProfileStats?
    var viewerContext: ViewerContext?
}
