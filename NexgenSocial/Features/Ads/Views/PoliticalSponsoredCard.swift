import SwiftUI

/// A political ad in the feed. Labelled "PAID POLITICAL AD" rather than
/// "SPONSORED", and it carries the "Paid for by" line and a link into the
/// public archive: those two are the disclosure the archive exists to keep,
/// so they belong on the ad itself, not only after the fact.
struct PoliticalSponsoredCard: View {
    let ad: PoliticalAd
    /// IMPRESSION and CLICK, routed out through the caller like the
    /// sponsored card's: views don't reach the network directly.
    let record: (String) async -> Void

    @State private var recordedImpression = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("PAID POLITICAL AD")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.slate400)
                if let page = ad.page?.name {
                    Text(page)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.slate400)
                }
            }

            if let headline = ad.headline {
                Text(headline)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
            }

            if let body = ad.body {
                Text(body)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.slate300)
            }

            if let url = APIClient.mediaURL(ad.mediaUrl ?? ad.imageUrl) {
                CachedImage(url: url) { phase in
                    if case .success(let image) = phase {
                        image.resizable().aspectRatio(contentMode: .fit)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            Text("Paid for by \(ad.paidForBy ?? "undisclosed")")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.slate300)

            HStack {
                if let raw = ad.targetUrl, let url = URL(string: raw) {
                    Button("Learn more") {
                        Task { await record("CLICK") }
                        UIApplication.shared.open(url)
                    }
                    .font(.system(size: 13))
                    .tint(Theme.cyan400)
                }
                Spacer()
                NavigationLink { PoliticalArchiveView() } label: {
                    Text("Why this ad, and who paid")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.slate400)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
        .task {
            guard !recordedImpression else { return }
            recordedImpression = true
            await record("IMPRESSION")
        }
    }
}
