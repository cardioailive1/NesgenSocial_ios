import Foundation

@MainActor
final class ProfileSetupViewModel: ObservableObject {
    @Published private(set) var allInterests: [Interest] = []
    @Published private(set) var privacy = PrivacySettings()
    @Published private(set) var selectedInterestIds: Set<String> = []
    @Published private(set) var isSaving = false

    @Published var gender = ""
    @Published var relationshipStatus = ""
    @Published var occupation = ""
    @Published var education = ""
    @Published var city = ""
    @Published var country = ""
    @Published var bio = ""
    @Published var birthDate = Date()
    @Published var hasBirthDate = false
    @Published var hasChildren = false

    @Published var statusMessage: String?
    @Published var errorMessage: String?

    func load() async {
        do {
            let response = try await ProfileService.me()
            privacy = response.privacySettings ?? PrivacySettings()

            gender = response.profile.gender ?? ""
            relationshipStatus = response.profile.relationshipStatus ?? ""
            occupation = response.profile.occupation ?? ""
            education = response.profile.education ?? ""
            city = response.profile.city ?? ""
            country = response.profile.country ?? ""
            bio = response.profile.bio ?? ""
            hasChildren = response.profile.hasChildren ?? false
            selectedInterestIds = Set((response.profile.interests ?? []).map(\.id))

            if let raw = response.profile.birthDate,
               let parsed = ISO8601DateFormatter().date(from: raw) {
                birthDate = parsed
                hasBirthDate = true
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        do {
            allInterests = try await ProfileService.allInterests()
        } catch {
            errorMessage = errorMessage ?? error.localizedDescription
        }
    }

    func isSelected(_ interest: Interest) -> Bool {
        selectedInterestIds.contains(interest.id)
    }

    func toggleInterest(_ interest: Interest) async {
        if selectedInterestIds.contains(interest.id) {
            selectedInterestIds.remove(interest.id)
        } else {
            selectedInterestIds.insert(interest.id)
        }
        do {
            try await ProfileService.setInterests(Array(selectedInterestIds))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func save() async {
        isSaving = true
        defer { isSaving = false }
        errorMessage = nil

        var body: [String: Any] = [
            "gender": gender,
            "relationshipStatus": relationshipStatus,
            "occupation": occupation,
            "education": education,
            "city": city,
            "country": country,
            "bio": bio,
            "hasChildren": hasChildren,
            "timezone": TimeZone.current.identifier,
        ]
        // Sent as a plain date because the server's own age bounds are what
        // reject bad values; an empty string clears it.
        body["birthDate"] = hasBirthDate
            ? ISO8601DateFormatter().string(from: birthDate)
            : ""

        do {
            try await ProfileService.update(body)
            statusMessage = "Profile saved."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func savePrivacy(_ field: String, _ value: Bool) async {
        do {
            privacy = try await ProfileService.setPrivacy(field, value)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
