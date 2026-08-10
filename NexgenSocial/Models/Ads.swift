import Foundation

struct Ad: Codable, Identifiable {
    let id: String
    let headline: String
    var body: String?
    var targetUrl: String?
    var imageUrl: String?
    var category: String?
    var active: Bool?
    var paymentStatus: String?
    var budgetCents: Int?
    var durationDays: Int?
    var reachCap: Int?
    var createdAt: String?
    /// Sent only by the serving endpoint, so the UI can say honestly whether
    /// this ad was matched to the viewer or shown untargeted.
    var wasTargeted: Bool?
}

struct AdStarter: Codable {
    let priceCents: Int
    let durationDays: Int
    let reachCap: Int
}

struct AdPricing: Codable {
    let basePriceCents: Int
    let baseDurationDays: Int
    let baseReach: Int
    var paymentUrl: String?
    var starter: AdStarter?
}

/// Reach is deliberately nullable: the server withholds the exact figure
/// below its k-anonymity threshold rather than rounding it, so a missing
/// number here means "suppressed", not "zero".
struct AudienceEstimate: Codable {
    var estimatedReach: Int?
    let suppressed: Bool
    var minimumThreshold: Int?
    var note: String?
}

struct AdPerformance: Codable {
    let impressions: Int
    let clicks: Int
    let conversions: Int
    var clickThroughRate: Double?
    var conversionRate: Double?
    var revenueCents: Int?
    var distinctReach: Int?
    var distinctReachSuppressed: Bool?
}

struct AdInsights: Codable {
    let ad: Ad
    let performance: AdPerformance
}

struct AdsResponse: Codable { let ads: [Ad] }
struct AdCreateResponse: Codable {
    let ad: Ad
    var paymentUrl: String?
    var message: String?
}
struct CheckoutResponse: Codable {
    var checkoutUrl: String?
    var addedDays: Int?
    var addedReach: Int?
}
