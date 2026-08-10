import SwiftUI

struct AdInsightsView: View {
    let ad: Ad
    @StateObject private var model: AdInsightsViewModel

    init(ad: Ad) {
        self.ad = ad
        _model = StateObject(wrappedValue: AdInsightsViewModel(ad: ad))
    }

    var body: some View {
        ZStack {
            Theme.navy950.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(ad.headline)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)

                    if let performance = model.insights?.performance {
                        VStack(spacing: 0) {
                            statRow("Impressions", performance.impressions.formatted())
                            statRow("Clicks", performance.clicks.formatted())
                            statRow("Click-through", "\(performance.clickThroughRate ?? 0)%")
                            statRow("Conversions", performance.conversions.formatted())
                            statRow("Revenue", money(performance.revenueCents))
                            statRow("People reached", performance.distinctReach.map { $0.formatted() } ?? "Withheld")
                        }
                        .padding(14)
                        .card()

                        if performance.distinctReachSuppressed == true {
                            Text("Reach is withheld while too few people have seen this ad — a small enough audience can be identified from an exact count.")
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.slate400)
                        }
                    } else {
                        ProgressView().tint(Theme.cyan400)
                    }

                    SectionHeader("Extend")
                    HStack(spacing: 8) {
                        TextField("Top-up in cents", text: $model.topUp)
                            .keyboardType(.numberPad)
                            .fieldStyle()
                        Button("Extend") { Task { await extendCampaign() } }
                    }
                    Text("Minimum $5.00. More money buys proportionally more days and reach. Only works on a campaign that's already paid for.")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.slate400)

                    if let errorMessage = model.errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.danger)
                    }
                }
                .padding(14)
            }
        }
        .navigationTitle("Performance")
        .navigationBarTitleDisplayMode(.inline)
        .tint(Theme.cyan400)
        .task { await model.load() }
    }

    private func statRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(Theme.slate400)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
        }
        .padding(.vertical, 5)
    }

    private func extendCampaign() async {
        guard let url = await model.extendCheckoutURL() else { return }
        await UIApplication.shared.open(url)
    }
}
