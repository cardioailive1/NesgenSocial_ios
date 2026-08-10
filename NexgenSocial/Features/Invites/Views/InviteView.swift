import SwiftUI

/// Invite links.
///
/// No platform lets a third-party app read your friends list any more, so
/// "invite your friends" means generating a link you share yourself. That's
/// what this is: a trackable token, handed to the system share sheet.
struct InviteView: View {
    @StateObject private var model = InviteViewModel()
    @State private var shareLink: ShareLink?

    /// Wrapper so `.sheet(item:)` has something Identifiable to key on.
    struct ShareLink: Identifiable {
        let id = UUID()
        let url: URL
    }

    var body: some View {
        ZStack {
            Theme.navy950.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Share a link")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                        Text("Each link is tracked, so you can see which invites you've sent. Whoever signs up through it is connected to you automatically.")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.slate400)

                        Button(model.isCreating ? "Creating…" : "Create invite link") {
                            Task { await create() }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.cyan400)
                        .disabled(model.isCreating)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card()

                    if let errorMessage = model.errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.danger)
                    }

                    SectionHeader("Sent invites")
                    if model.invites.isEmpty {
                        Text("No invites yet.")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.slate400)
                            .padding(20)
                            .frame(maxWidth: .infinity)
                            .card()
                    }
                    ForEach(model.invites) { invite in
                        Button { shareLink = link(for: invite).map(ShareLink.init) } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(invite.contact ?? invite.channel ?? "Link")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(.white)
                                    Text(invite.token)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(Theme.slate400)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Image(systemName: "square.and.arrow.up")
                                    .foregroundStyle(Theme.cyan400)
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity)
                            .card()
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(14)
            }
        }
        .navigationTitle("Invite")
        .navigationBarTitleDisplayMode(.inline)
        .tint(Theme.cyan400)
        .task { await model.load() }
        .sheet(item: $shareLink) { item in
            ShareSheet(items: [item.url])
        }
    }

    private func link(for invite: Invite) -> URL? {
        URL(string: "\(AppConfig.websiteURL)/signup?ref=\(invite.token)")
    }

    private func create() async {
        guard let invite = await model.create() else { return }
        shareLink = link(for: invite).map { ShareLink(url: $0) }
    }
}

/// UIActivityViewController bridge — SwiftUI's own ShareLink is iOS 16+, but
/// the name collides with the wrapper above, so the UIKit control is the
/// less confusing choice here.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
