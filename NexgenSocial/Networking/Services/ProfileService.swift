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
