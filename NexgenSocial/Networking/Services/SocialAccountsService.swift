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

    static func createInvite(channel: String = "link") async throws -> Invite {
        try await APIClient.shared.post(APIEndpoints.SocialAccounts.invites,
                                        body: ["channel": channel],
                                        as: InviteResponse.self).invite
    }
}
