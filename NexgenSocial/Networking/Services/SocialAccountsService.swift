import Foundation

/// Linked third-party accounts and the referral invite links.
enum SocialAccountsService {

    static func accounts() async throws -> [SocialAccount] {
        try await APIClient.shared
            .get(APIEndpoints.SocialAccounts.root, as: AccountsResponse.self).accounts
    }

    static func connect(_ provider: String, displayName: String) async throws {
        _ = try await APIClient.shared.post(APIEndpoints.SocialAccounts.connect(provider),
                                            body: ["displayName": displayName],
                                            as: EmptyResponse.self)
    }

    static func disconnect(_ provider: String) async throws {
        _ = try await APIClient.shared.delete(APIEndpoints.SocialAccounts.account(provider))
    }

    static func invites() async throws -> [Invite] {
        try await APIClient.shared
            .get(APIEndpoints.SocialAccounts.invites, as: InvitesResponse.self).invites
    }

    /// Public, no token required: turns an invite code into the person who
    /// sent it. Throws for an invalid or expired code.
    static func invite(token: String) async throws -> Invite {
        try await APIClient.shared
            .get(APIEndpoints.SocialAccounts.invite(token), as: InviteResponse.self).invite
    }

    /// `contact` is what the invite was addressed to (an email address), so
    /// each recipient can be tracked separately in the sent list.
    static func createInvite(channel: String = "link", contact: String? = nil) async throws -> Invite {
        var body: [String: Any] = ["channel": channel]
        body["contact"] = contact
        return try await APIClient.shared.post(APIEndpoints.SocialAccounts.invites,
                                               body: body,
                                               as: InviteResponse.self).invite
    }
}
