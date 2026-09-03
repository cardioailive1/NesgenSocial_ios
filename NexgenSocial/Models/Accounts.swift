import Foundation

struct SocialAccount: Codable, Identifiable {
    let id: String
    let provider: String
    var displayName: String?
    var connectedAt: String?
}

struct Invite: Codable, Identifiable {
    let id: String
    let token: String
    var channel: String?
    var contact: String?
    var createdAt: String?
    /// Only returned by the public lookup, so the signup screen can say who
    /// invited you. Not a `User`: the public route deliberately selects only
    /// these three fields, with no id.
    var sender: InviteSender?
}

struct InviteSender: Codable {
    let username: String
    var displayName: String?
    var avatarUrl: String?
}

struct AccountsResponse: Codable { let accounts: [SocialAccount] }
struct InvitesResponse: Codable { let invites: [Invite] }
struct InviteResponse: Codable { let invite: Invite }

// MARK: - Premium

struct TierResponse: Codable { let tier: String }

// MARK: - Generic envelopes

struct APIMessage: Codable { let error: String? }
