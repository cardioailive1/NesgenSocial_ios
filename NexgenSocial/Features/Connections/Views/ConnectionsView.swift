import SwiftUI

/// Linked external accounts.
///
/// The server records the link without an OAuth handshake, because none of
/// the provider client secrets are configured yet. That means connecting
/// here marks the account as linked and nothing more — it does not sign you
/// in anywhere or read anything from that platform. The screen says so
/// rather than implying a connection it doesn't have.
struct ConnectionsView: View {
    @StateObject private var model = ConnectionsViewModel()

    private let providers = [
        ("FACEBOOK", "Facebook"),
        ("INSTAGRAM", "Instagram"),
        ("X", "X"),
        ("LINKEDIN", "LinkedIn"),
        ("TIKTOK", "TikTok"),
        ("GOOGLE", "Google"),
    ]

    var body: some View {
        ZStack {
            Theme.navy950.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Linking records the handle on your profile. It doesn't sign you in to that platform or read anything from it.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.slate400)

                    ErrorBanner(message: model.errorMessage)

                    ForEach(providers, id: \.0) { provider, label in
                        row(provider: provider, label: label)
                    }
                }
                .padding(14)
            }
        }
        .navigationTitle("Connections")
        .navigationBarTitleDisplayMode(.inline)
        .tint(Theme.cyan400)
        .task { await model.load() }
        .alert("Link \(model.namingProvider.map(displayLabel) ?? "")", isPresented: Binding(
            get: { model.namingProvider != nil },
            set: { if !$0 { model.namingProvider = nil } }
        )) {
            TextField("Your handle there", text: $model.displayName)
            Button("Cancel", role: .cancel) { model.namingProvider = nil }
            Button("Link") {
                if let provider = model.namingProvider { Task { await model.connect(provider) } }
            }
        }
    }

    private func row(provider: String, label: String) -> some View {
        let existing = model.account(for: provider)
        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                if let name = existing?.displayName, !name.isEmpty {
                    Text(name)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.slate400)
                }
            }
            Spacer()
            if existing != nil {
                Button("Disconnect") { Task { await model.disconnect(provider) } }
                    .font(.system(size: 13))
                    .tint(Theme.danger)
            } else {
                Button("Link") {
                    model.displayName = ""
                    model.namingProvider = provider
                }
                .font(.system(size: 13))
            }
        }
        .disabled(model.working == provider)
        .padding(14)
        .card()
    }

    private func displayLabel(_ provider: String) -> String {
        providers.first { $0.0 == provider }?.1 ?? provider
    }

}
