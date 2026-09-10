import Foundation
import SwiftUI
import PhotosUI

@MainActor
final class MarketplaceViewModel: ObservableObject, LoadingViewModel {
    @Published private(set) var listings: [MarketListing] = []
    @Published var searchText = ""
    @Published private(set) var isPublishing = false
    @Published var errorMessage: String?

    // New listing form
    @Published var title = ""
    @Published var listingDescription = ""
    @Published var price = ""
    @Published var condition = ""
    @Published var location = ""
    @Published var attachments: [PickedAttachment] = []

    func load() async {
        await attempt {
            listings = try await MarketplaceService.listings(matching: searchText.trimmingCharacters(in: .whitespaces))
        }
    }

    func addAttachments(_ items: [PhotosPickerItem]) async {
        attachments += await AttachmentLoader.load(items)
    }

    /// Returns true when the listing published, so the view can close the form.
    func publish() async -> Bool {
        guard !title.isEmpty, !listingDescription.isEmpty, let priceValue = Double(price) else {
            errorMessage = "Title, description, and price are required."
            return false
        }
        isPublishing = true
        defer { isPublishing = false }
        do {
            try await MarketplaceService.create(title: title,
                                                description: listingDescription,
                                                priceCents: Int((priceValue * 100).rounded()),
                                                condition: condition,
                                                location: location,
                                                attachments: attachments)
            title = ""; listingDescription = ""; price = ""; condition = ""; location = ""
            attachments = []
            errorMessage = nil
            await load()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// Photos picked for a listing that already exists. The server returns the
    /// updated listing, so the card's carousel and counts refresh in place.
    func addPhotos(_ items: [PhotosPickerItem], to listing: MarketListing) async {
        let picked = await AttachmentLoader.load(items)
        guard !picked.isEmpty else { return }
        do {
            let updated = try await MarketplaceService.addMedia(picked, to: listing.id)
            if let index = listings.firstIndex(where: { $0.id == listing.id }) {
                listings[index] = updated
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// The mirror of `addPhotos`. The delete route returns no listing, so the
    /// item and the counts behind the card's meta line are updated here.
    func removePhoto(_ item: MediaItem, from listing: MarketListing) async {
        do {
            try await MarketplaceService.removeMedia(item.id, from: listing.id)
            guard let index = listings.firstIndex(where: { $0.id == listing.id }) else { return }
            var updated = listings[index]
            updated.media?.removeAll { $0.id == item.id }
            if item.kind == .video {
                updated.videoCount = max((updated.videoCount ?? 1) - 1, 0)
            } else {
                updated.photoCount = max((updated.photoCount ?? 1) - 1, 0)
            }
            updated.coverUrl = updated.media?.first { $0.kind == .photo }?.url
            listings[index] = updated
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(_ listing: MarketListing) async {
        do {
            try await MarketplaceService.delete(listing.id)
            listings.removeAll { $0.id == listing.id }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Saves the seller's edits. Returns true so the sheet can close only
    /// when the change actually landed.
    func saveEdits(to listing: MarketListing,
                   title: String,
                   description: String,
                   price: String,
                   condition: String,
                   location: String) async -> Bool {
        guard !title.isEmpty, !description.isEmpty, let priceValue = Double(price) else {
            errorMessage = "Title, description, and price are required."
            return false
        }
        do {
            let updated = try await MarketplaceService.update(listing.id, fields: [
                "title": title,
                "description": description,
                "priceCents": Int((priceValue * 100).rounded()),
                "condition": condition,
                "location": location,
            ])
            if let index = listings.firstIndex(where: { $0.id == listing.id }) {
                listings[index] = updated
            }
            errorMessage = nil
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func markSold(_ listing: MarketListing) async {
        do {
            try await MarketplaceService.markSold(listing.id)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
