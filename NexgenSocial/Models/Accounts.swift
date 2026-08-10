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
}

struct AccountsResponse: Codable { let accounts: [SocialAccount] }
struct InvitesResponse: Codable { let invites: [Invite] }
struct InviteResponse: Codable { let invite: Invite }

// MARK: - Premium

struct TierResponse: Codable { let tier: String }

// MARK: - Generic envelopes

struct APIMessage: Codable { let error: String? }
