import Foundation

/// Marketplace listings: browse, sell, mark sold, add photos, withdraw.
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

    /// Appended after whatever the listing already has -- the server assigns
    /// the positions -- and it returns the listing with its new media.
    static func addMedia(_ attachments: [PickedAttachment],
                         to listingId: String) async throws -> MarketListing {
        try await APIClient.shared.upload(APIEndpoints.Marketplace.media(listingId),
                                          files: attachments.uploadFiles,
                                          as: ListingResponse.self).listing
    }

    /// Takes one photo or video back off a listing. The route answers 204
    /// with no body, so the caller drops the item from its own copy rather
    /// than waiting for a refreshed listing.
    static func removeMedia(_ mediaId: String, from listingId: String) async throws {
        _ = try await APIClient.shared
            .delete(APIEndpoints.Marketplace.mediaItem(listingId, mediaId: mediaId))
    }

    /// Only the seller gets through; anyone else is told the listing isn't
    /// there rather than that it isn't theirs.
    static func delete(_ listingId: String) async throws {
        _ = try await APIClient.shared.delete(APIEndpoints.Marketplace.listing(listingId))
    }

    static func markSold(_ listingId: String) async throws {
        _ = try await update(listingId, fields: ["status": "SOLD"])
    }

    /// The seller's own edits. The route takes title, description,
    /// priceCents, condition, location and status, applies whichever are
    /// present, and answers with the whole listing.
    @discardableResult
    static func update(_ listingId: String, fields: [String: Any]) async throws -> MarketListing {
        try await APIClient.shared.patch(APIEndpoints.Marketplace.listing(listingId),
                                         body: fields,
                                         as: ListingResponse.self).listing
    }
}
