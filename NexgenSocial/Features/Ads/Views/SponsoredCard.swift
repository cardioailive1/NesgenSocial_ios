import SwiftUI

/// An ad in the feed, labelled as one. The "why am I seeing this" line is
/// not decoration: the server tells us whether the ad was matched to this
/// viewer, and hiding that would make the label meaningless.
struct SponsoredCard: View {
    let ad: Ad
    @State private var recordedImpression = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SPONSORED")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Theme.slate400)

            Text(ad.headline)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)

            if let body = ad.body {
                Text(body)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.slate300)
            }

            if let url = APIClient.mediaURL(ad.imageUrl) {
                AsyncImage(url: url) { phase in
                    if case .success(let image) = phase {
                        image.resizable().aspectRatio(contentMode: .fit)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

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
                Text(ad.wasTargeted == true ? "Matched to your interests" : "Shown to everyone")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.slate400)
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

    private func record(_ type: String) async {
        await AdsService.track(type, adId: ad.id)
    }
}
