import Foundation

enum PremiumService {

    static func currentTier() async throws -> String {
        try await APIClient.shared.get(APIEndpoints.Premium.status, as: TierResponse.self).tier
    }

    /// Returns the tier the account is on afterwards, so the caller doesn't
    /// have to guess what "upgraded" resolved to.
    static func setPremium(_ premium: Bool) async throws -> String {
        let path = premium ? APIEndpoints.Premium.upgrade : APIEndpoints.Premium.downgrade
        return try await APIClient.shared.post(path, as: TierResponse.self).tier
    }
}
