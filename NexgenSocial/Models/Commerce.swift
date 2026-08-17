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
    var responsibilities: String?
    var requirements: String?
    var applyUrl: String?
    var companyLogoUrl: String?
    var status: String?
    var applicationCount: Int?
    var isOwner: Bool?
    var poster: User?
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
    var status: String?
    var photoCount: Int?
    var videoCount: Int?
    var createdAt: String?

    var priceText: String {
        String(format: "$%.2f", Double(priceCents) / 100.0)
    }
}

/// An application the viewer submitted. `job` is the trimmed copy the server
/// returns here — not the full posting.
struct JobApplication: Codable, Identifiable {
    let id: String
    var status: String
    var coverLetter: String?
    var resumeUrl: String?
    var createdAt: String?
    var job: JobSummary?

    struct JobSummary: Codable {
        let id: String
        let title: String
        let companyName: String
        var location: String?
        var arrangement: String?
        var status: String?
    }
}

/// An application seen from the employer's side, with the applicant attached.
struct JobApplicant: Codable, Identifiable {
    let id: String
    var status: String
    var coverLetter: String?
    var resumeUrl: String?
    var createdAt: String?
    var applicant: User
}

struct JobsResponse: Codable { let jobs: [JobPosting] }
struct JobResponse: Codable { let job: JobPosting }
struct JobApplicationsResponse: Codable { let applications: [JobApplication] }
struct JobApplicantsResponse: Codable { let applications: [JobApplicant] }
struct ListingsResponse: Codable { let listings: [MarketListing] }
struct ListingResponse: Codable { let listing: MarketListing }
