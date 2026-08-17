import SwiftUI
import PhotosUI

/// Listings to browse, and the form to sell something — the same flow as the
/// web Marketplace page.
struct MarketplaceView: View {
    @EnvironmentObject private var session: AuthSession
    @StateObject private var model = MarketplaceViewModel()

    @State private var showingForm = false
    @State private var pickedItems: [PhotosPickerItem] = []

    var body: some View {
        ZStack {
            Theme.navy950.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ErrorBanner(message: model.errorMessage)

                    if showingForm { sellForm }

                    if model.listings.isEmpty {
                        Text(model.searchText.isEmpty
                             ? "No listings yet — be the first to sell something."
                             : "Nothing matches that search.")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.slate400)
                            .frame(maxWidth: .infinity)
                            .padding(24)
                            .card()
                    }

                    ForEach(model.listings) { listing in
                        ListingCard(listing: listing,
                                    isMine: listing.seller?.username == session.currentUser?.username) {
                            await model.markSold(listing)
                        }
                    }
                }
                .padding(14)
            }
            .refreshable { await model.load() }
        }
        .navigationTitle("Marketplace")
        .navigationBarTitleDisplayMode(.inline)
        .tint(Theme.cyan400)
        .searchable(text: $model.searchText, prompt: "Search listings…")
        .onChange(of: model.searchText) { _, _ in Task { await model.load() } }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(showingForm ? "Cancel" : "Sell something") {
                    showingForm.toggle()
                }
                .font(.system(size: 13, weight: .semibold))
            }
        }
        .task { await model.load() }
    }

    private var sellForm: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("New listing")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.slate400)
                .textCase(.uppercase)

            TextField("What are you selling?", text: $model.title).fieldStyle()
            TextField("Describe it — condition, details, why you're selling",
                      text: $model.listingDescription, axis: .vertical)
                .lineLimit(3...8)
                .fieldStyle()
            HStack(spacing: 8) {
                TextField("Price (USD)", text: $model.price)
                    .keyboardType(.decimalPad)
                    .fieldStyle()
                TextField("Condition (e.g. Like new)", text: $model.condition).fieldStyle()
            }
            TextField("Location (e.g. Columbus, OH)", text: $model.location).fieldStyle()

            PhotosPicker(selection: $pickedItems, maxSelectionCount: 10,
                         matching: .any(of: [.images, .videos])) {
                Label("Add photos & video (up to 10)", systemImage: "photo.on.rectangle.angled")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.cyan300)
            }
            if !model.attachments.isEmpty {
                AttachmentStrip(attachments: $model.attachments)
            }
            Text("The first photo becomes the cover image. Listings with several photos and a short video get far more interest.")
                .font(.system(size: 11))
                .foregroundStyle(Theme.slate400)

            Button(model.isPublishing ? "Publishing…" : "Publish listing") {
                Task { if await model.publish() { showingForm = false } }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(model.isPublishing)
        }
        .foregroundStyle(.white)
        .padding(14)
        .card()
        .onChange(of: pickedItems) { _, newItems in
            Task {
                await model.addAttachments(newItems)
                pickedItems = []
            }
        }
    }
}

struct ListingCard: View {
    let listing: MarketListing
    let isMine: Bool
    let onMarkSold: () async -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let media = listing.media, !media.isEmpty {
                MediaCarousel(items: media)
            }

            HStack(alignment: .firstTextBaseline) {
                Text(listing.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                Spacer(minLength: 0)
                Text(listing.priceText)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.cyan300)
            }

            Text(listing.description)
                .font(.system(size: 12))
                .foregroundStyle(Theme.slate400)

            Text(metaLine)
                .font(.system(size: 11))
                .foregroundStyle(Theme.slate400)

            if isMine {
                Button("Mark as sold") { Task { await onMarkSold() } }
                    .font(.system(size: 12))
                    .buttonStyle(GhostButtonStyle())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .card()
    }

    private var metaLine: String {
        var parts: [String] = []
        if let condition = listing.condition, !condition.isEmpty { parts.append(condition) }
        if let location = listing.location, !location.isEmpty { parts.append(location) }
        let photos = listing.photoCount ?? 0
        let videos = listing.videoCount ?? 0
        if photos > 0 { parts.append("\(photos) photo\(photos == 1 ? "" : "s")") }
        if videos > 0 { parts.append("\(videos) video\(videos == 1 ? "" : "s")") }
        if let seller = listing.seller { parts.append("Seller: @\(seller.username)") }
        return parts.joined(separator: " · ")
    }
}
