import Foundation

/// Marketplace listings: browse, sell, mark sold.
enum MarketplaceService {

    static func listings(matching query: String = "") async throws -> [MarketListing] {
        try await APIClient.shared
            .get(APIEndpoints.Marketplace.listings(query: query), as: ListingsResponse.self).listings
    }

    static func create(title: String,
                       description: String,
                       priceCents: Int,
                       condition: String,
                       location: String,
                       attachments: [PickedAttachment]) async throws {
        var fields = ["title": title, "description": description, "priceCents": String(priceCents)]
        if !condition.isEmpty { fields["condition"] = condition }
        if !location.isEmpty { fields["location"] = location }
        _ = try await APIClient.shared.upload(APIEndpoints.Marketplace.root,
                                              fields: fields,
                                              files: attachments.uploadFiles,
                                              as: ListingResponse.self)
    }

    static func markSold(_ listingId: String) async throws {
        _ = try await APIClient.shared.patch(APIEndpoints.Marketplace.listing(listingId),
                                             body: ["status": "SOLD"],
                                             as: ListingResponse.self)
    }
}
