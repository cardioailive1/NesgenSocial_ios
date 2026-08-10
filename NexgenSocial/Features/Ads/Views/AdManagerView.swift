import SwiftUI

/// Ad campaigns: plan an audience, create a campaign, pay, read the numbers.
///
/// Card payment happens in Stripe Checkout, which the server hands back as a
/// URL. Opening it in Safari rather than an embedded web view is deliberate:
/// people should be able to see the address bar of the page they're typing a
/// card number into.
struct AdManagerView: View {
    @StateObject private var model = AdManagerViewModel()
    @State private var showingCreate = false

    var body: some View {
        ZStack {
            Theme.navy950.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let pricing = model.pricing {
                        pricingCard(pricing)
                    }

                    if let errorMessage = model.errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.danger)
                    }

                    NavigationLink {
                        AudiencePlannerView()
                    } label: {
                        Label("Estimate an audience", systemImage: "person.3.sequence.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.cyan400)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .card()
                    }

                    SectionHeader("Running campaigns")
                    if model.ads.isEmpty {
                        Text("No campaigns yet.")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.slate400)
                            .padding(20)
                            .frame(maxWidth: .infinity)
                            .card()
                    }
                    ForEach(model.ads) { ad in
                        NavigationLink {
                            AdInsightsView(ad: ad)
                        } label: {
                            AdRow(ad: ad)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(14)
            }
        }
        .navigationTitle("Ads")
        .navigationBarTitleDisplayMode(.inline)
        .tint(Theme.cyan400)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingCreate = true } label: { Image(systemName: "plus") }
            }
        }
        .task { await model.load() }
        .sheet(isPresented: $showingCreate) {
            NewAdView { await model.load() }
        }
    }

    private func pricingCard(_ pricing: AdPricing) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(money(pricing.basePriceCents))
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Theme.cyan400)
            Text("\(pricing.baseDurationDays) day, up to \(pricing.baseReach.formatted()) people.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.slate300)
            Text("Every campaign starts on the same package. You can top one up later, once you've seen how it performs.")
                .font(.system(size: 11))
                .foregroundStyle(Theme.slate400)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}

func money(_ cents: Int?) -> String {
    let value = Double(cents ?? 0) / 100
    return value.formatted(.currency(code: "USD"))
}
