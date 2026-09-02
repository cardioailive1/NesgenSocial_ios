import SwiftUI

/// Subscription tier. The backend's upgrade/downgrade endpoints flip the
/// tier directly — real payment goes through Stripe Checkout on the web,
/// so this screen states that rather than pretending to take money.
struct PremiumView: View {
    @StateObject private var model = PremiumViewModel()

    private var isPremium: Bool { model.isPremium }

    var body: some View {
        ZStack {
            Theme.navy950.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(isPremium ? "Premium" : "Free")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(isPremium ? Theme.cyan400 : .white)
                        Text(isPremium
                             ? "You have Premium. Ad tools and the extended marketplace are unlocked."
                             : "Premium unlocks ad campaigns and extended marketplace listings.")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.slate300)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .card()

                    ErrorBanner(message: model.errorMessage)

                    Button(isPremium ? "Switch back to Free" : "Upgrade to Premium") {
                        Task { await model.toggleTier() }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(isPremium ? Theme.navy800 : Theme.cyan400)
                    .disabled(model.isWorking)

                    Text("Card payments for ad campaigns run through Stripe Checkout in the web app. This screen changes your tier only.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.slate400)
                }
                .padding(14)
            }
        }
        .navigationTitle("Premium")
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load() }
    }
}
