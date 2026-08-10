import Foundation

struct JobPosting: Codable, Identifiable {
    let id: String
    let title: String
    let companyName: String
    var description: String?
    var location: String?
    var arrangement: String?
    var employmentType: String?
    var salaryMin: Int?
    var salaryMax: Int?
    var salaryCurrency: String?
    var salaryPeriod: String?
    var appliedByViewer: Bool?
    var createdAt: String?

    var salaryText: String? {
        guard salaryMin != nil || salaryMax != nil else { return nil }
        let cur = salaryCurrency ?? "USD"
        let per = ["YEAR": "/yr", "MONTH": "/mo", "HOUR": "/hr"][salaryPeriod ?? "YEAR"] ?? ""
        let fmt: (Int) -> String = { NumberFormatter.localizedString(from: NSNumber(value: $0), number: .decimal) }
        if let lo = salaryMin, let hi = salaryMax { return "\(cur) \(fmt(lo))–\(fmt(hi))\(per)" }
        return "\(cur) \(fmt(salaryMin ?? salaryMax ?? 0))\(per)"
    }
}

struct MarketListing: Codable, Identifiable {
    let id: String
    let title: String
    let description: String
    let priceCents: Int
    var condition: String?
    var location: String?
    var seller: User?
    var media: [MediaItem]?
    var coverUrl: String?

    var priceText: String {
        String(format: "$%.2f", Double(priceCents) / 100.0)
    }
}

struct JobsResponse: Codable { let jobs: [JobPosting] }
struct ListingsResponse: Codable { let listings: [MarketListing] }
