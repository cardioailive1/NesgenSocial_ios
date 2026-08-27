import Foundation

/// The signed-in user's own profile: details, interests, privacy, and saved
/// places.
enum ProfileService {

    static func me() async throws -> ProfileMeResponse {
        try await APIClient.shared.get(APIEndpoints.Profile.me, as: ProfileMeResponse.self)
    }

    static func update(_ fields: [String: Any]) async throws {
        _ = try await APIClient.shared.patch(APIEndpoints.Profile.me, body: fields,
                                             as: ProfileResponse.self)
    }

    /// Public profile plus follower/following/friend counts.
    static func profile(_ username: String) async throws -> UserProfileResponse {
        try await APIClient.shared.get(APIEndpoints.Users.profile(username),
                                       as: UserProfileResponse.self)
    }

    /// Permanently removes the account and everything attached to it. There
    /// is no undo and no grace period -- the server deletes on the spot.
    static func deleteAccount() async throws {
        _ = try await APIClient.shared.delete(APIEndpoints.Users.me)
    }

    /// The avatar route takes the file under the field name `avatar`, not the
    /// `media` name the post and message uploads use.
    static func uploadAvatar(_ image: PickedAttachment) async throws -> User {
        try await APIClient.shared.upload(
            APIEndpoints.Users.avatar,
            files: [(name: "avatar", filename: image.filename,
                     mimeType: image.mimeType, data: image.data)],
            as: MeResponse.self).user
    }

    static func allInterests() async throws -> [Interest] {
        try await APIClient.shared
            .get(APIEndpoints.Profile.interests, as: InterestsResponse.self).interests
    }

    static func setInterests(_ ids: [String]) async throws {
        _ = try await APIClient.shared.put(APIEndpoints.Profile.myInterests,
                                           body: ["interestIds": ids],
                                           as: InterestsResponse.self)
    }

    static func setPrivacy(_ field: String, _ value: Any) async throws -> PrivacySettings {
        try await APIClient.shared.patch(APIEndpoints.Profile.privacy,
                                         body: [field: value],
                                         as: PrivacyResponse.self).privacySettings
    }

    // MARK: - Places

    static func places() async throws -> [VisitedPlace] {
        try await APIClient.shared.get(APIEndpoints.Profile.places, as: PlacesResponse.self).places
    }

    static func geocode(_ query: String) async throws -> [GeocodeResult] {
        try await APIClient.shared
            .get(APIEndpoints.Profile.geocode(query), as: GeocodeResponse.self).results
    }

    static func addPlace(_ body: [String: Any]) async throws {
        _ = try await APIClient.shared.post(APIEndpoints.Profile.places, body: body,
                                            as: EmptyResponse.self)
    }

    static func removePlace(_ id: String) async throws {
        _ = try await APIClient.shared.delete(APIEndpoints.Profile.place(id))
    }
}
