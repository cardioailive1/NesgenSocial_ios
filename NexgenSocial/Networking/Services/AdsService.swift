import Foundation

enum AdsService {

    static func serve(limit: Int = 2) async throws -> [Ad] {
        try await APIClient.shared.get(APIEndpoints.Ads.serve(limit: limit), as: AdsResponse.self).ads
    }

    static func mine() async throws -> [Ad] {
        try await APIClient.shared.get(APIEndpoints.Ads.mine, as: AdsResponse.self).ads
    }

    static func pricing() async throws -> AdPricing {
        try await APIClient.shared.get(APIEndpoints.Ads.pricing, as: AdPricing.self)
    }

    static func insights(for adId: String) async throws -> AdInsights {
        try await APIClient.shared.get(APIEndpoints.Ads.insights(adId), as: AdInsights.self)
    }

    static func audienceEstimate(_ body: [String: Any]) async throws -> AudienceEstimate {
        try await APIClient.shared.post(APIEndpoints.Ads.estimate, body: body,
                                        as: AudienceEstimate.self)
    }

    static func create(fields: [String: String],
                       attachments: [PickedAttachment]) async throws -> AdCreateResponse {
        try await APIClient.shared.upload(APIEndpoints.Ads.mine,
                                          fields: fields,
                                          files: attachments.uploadFiles,
                                          as: AdCreateResponse.self)
    }

    static func checkoutURL(for adId: String) async throws -> URL? {
        let response = try await APIClient.shared.post(APIEndpoints.Ads.checkout(adId),
                                                       as: CheckoutResponse.self)
        return response.checkoutUrl.flatMap(URL.init(string:))
    }

    static func extendCheckoutURL(for adId: String, topUpCents: Int) async throws -> URL? {
        let response = try await APIClient.shared.post(APIEndpoints.Ads.extendCheckout(adId),
                                                       body: ["topUpCents": topUpCents],
                                                       as: CheckoutResponse.self)
        return response.checkoutUrl.flatMap(URL.init(string:))
    }

    /// Impressions and clicks. Fire-and-forget by design: a dropped analytics
    /// event must never surface as an error in the feed.
    static func track(_ type: String, adId: String) async {
        _ = try? await APIClient.shared.post(APIEndpoints.Ads.events,
                                             body: ["adId": adId, "type": type],
                                             as: EmptyResponse.self)
    }
}
