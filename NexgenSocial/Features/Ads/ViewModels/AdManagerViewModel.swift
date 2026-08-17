import Foundation

@MainActor
final class AdManagerViewModel: ObservableObject {
    @Published private(set) var ads: [Ad] = []
    @Published private(set) var pricing: AdPricing?
    @Published var errorMessage: String?

    func load() async {
        do {
            pricing = try await AdsService.pricing()
            ads = try await AdsService.mine()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

@MainActor
final class NewAdViewModel: ObservableObject {
    @Published var headline = ""
    @Published var bodyText = ""
    @Published var targetUrl = ""
    @Published var category = "GENERAL"
    @Published var attachments: [PickedAttachment] = []
    @Published private(set) var isSaving = false
    @Published private(set) var created: Ad?
    @Published var errorMessage: String?

    var canSave: Bool { !headline.isEmpty && !bodyText.isEmpty && !isSaving && created == nil }

    func save() async {
        isSaving = true
        defer { isSaving = false }
        do {
            created = try await AdsService.create(fields: ["headline": headline,
                                                           "body": bodyText,
                                                           "targetUrl": targetUrl,
                                                           "category": category],
                                                  attachments: attachments).ad
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Returns the Stripe Checkout URL for the ad just created, if any.
    func checkoutURL() async -> URL? {
        guard let ad = created else { return nil }
        do {
            guard let url = try await AdsService.checkoutURL(for: ad.id) else {
                errorMessage = "The server didn't return a checkout link."
                return nil
            }
            return url
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
}

@MainActor
final class AdInsightsViewModel: ObservableObject {
    @Published private(set) var insights: AdInsights?
    @Published var topUp = "5000"
    @Published var errorMessage: String?

    private let ad: Ad

    init(ad: Ad) { self.ad = ad }

    func load() async {
        do {
            insights = try await AdsService.insights(for: ad.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Returns the Stripe Checkout URL for the top-up, if any.
    func extendCheckoutURL() async -> URL? {
        errorMessage = nil
        do {
            guard let url = try await AdsService.extendCheckoutURL(for: ad.id,
                                                                   topUpCents: Int(topUp) ?? 0) else {
                errorMessage = "The server didn't return a checkout link."
                return nil
            }
            return url
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
}

@MainActor
final class AudiencePlannerViewModel: ObservableObject {
    @Published var minAge = ""
    @Published var maxAge = ""
    @Published var city = ""
    @Published var country = ""
    @Published private(set) var allInterests: [Interest] = []
    @Published private(set) var selectedInterestIds: Set<String> = []
    @Published private(set) var estimate: AudienceEstimate?
    @Published var errorMessage: String?

    func load() async {
        do {
            allInterests = try await ProfileService.allInterests()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func isSelected(_ interest: Interest) -> Bool {
        selectedInterestIds.contains(interest.id)
    }

    func toggleInterest(_ interest: Interest) {
        if selectedInterestIds.contains(interest.id) {
            selectedInterestIds.remove(interest.id)
        } else {
            selectedInterestIds.insert(interest.id)
        }
    }

    func runEstimate() async {
        errorMessage = nil
        var body: [String: Any] = [:]
        if let value = Int(minAge) { body["minAge"] = value }
        if let value = Int(maxAge) { body["maxAge"] = value }
        if !city.isEmpty { body["cities"] = [city] }
        if !country.isEmpty { body["countries"] = [country] }
        if !selectedInterestIds.isEmpty { body["interestIds"] = Array(selectedInterestIds) }

        do {
            estimate = try await AdsService.audienceEstimate(body)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
