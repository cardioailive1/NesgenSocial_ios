import SwiftUI

/// Political pages. Every page names the organization responsible for it —
/// that disclosure is enforced server-side, and shown here.
struct PoliticalView: View {
    @StateObject private var model = PoliticalViewModel()

    private let types = [("", "All"), ("CANDIDATE", "Candidates"),
                         ("PARTY", "Parties"), ("ADVOCACY", "Advocacy")]

    var body: some View {
        ZStack {
            Theme.navy950.ignoresSafeArea()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    Picker("Type", selection: $model.typeFilter) {
                        ForEach(types, id: \.0) { Text($0.1).tag($0.0) }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 14)

                    if model.pages.isEmpty {
                        Text("No pages here yet.")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.slate400)
                            .padding(.horizontal, 14)
                    }

                    ForEach(model.pages) { page in
                        NavigationLink { PoliticalPageView(page: page) } label: {
                            PoliticalPageCard(page: page)
                        }
                        .padding(.horizontal, 14)
                    }
                }
                .padding(.vertical, 12)
            }
            .refreshable { await model.load() }
        }
        .navigationTitle("Political")
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load() }
        .onChange(of: model.typeFilter) { _, _ in Task { await model.load() } }
    }
}

struct PoliticalPageCard: View {
    let page: PoliticalPage

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(url: page.avatarUrl, seed: page.id, size: 44)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(page.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                    if page.verified == true {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.cyan400)
                    }
                }
                // The responsible organization is the whole point of the
                // disclosure, so it is never truncated away.
                Text("Paid for / run by \(page.organization ?? "undisclosed")")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.slate400)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .card()
    }
}

struct PoliticalPageView: View {
    let page: PoliticalPage

    @StateObject private var model: PoliticalPageViewModel

    init(page: PoliticalPage) {
        self.page = page
        _model = StateObject(wrappedValue: PoliticalPageViewModel(page: page))
    }

    var body: some View {
        ZStack {
            Theme.navy950.ignoresSafeArea()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Run by \(page.organization ?? "undisclosed")")
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.slate300)
                            if let region = page.region {
                                Text(region)
                                    .font(.system(size: 12))
                                    .foregroundStyle(Theme.slate400)
                            }
                        }
                        Spacer(minLength: 0)
                        Button(model.isFollowing ? "Following" : "Follow") {
                            Task { await model.toggleFollow() }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(model.isFollowing ? Theme.navy800 : Theme.cyan400)
                        .font(.system(size: 13))
                    }
                    .padding(.horizontal, 14)

                    if let url = page.websiteUrl, let link = URL(string: url) {
                        Link("Website", destination: link)
                            .font(.system(size: 13))
                            .padding(.horizontal, 14)
                    }

                    SectionHeader("Posts")
                    ForEach(model.posts) { post in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(post.body)
                                .font(.system(size: 14))
                                .foregroundStyle(Theme.slate300)
                            if let media = post.media, !media.isEmpty {
                                MediaCarousel(items: media)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .card()
                        .padding(.horizontal, 14)
                    }
                }
                .padding(.vertical, 12)
            }
            .refreshable { await model.load() }
        }
        .navigationTitle(page.name)
        .navigationBarTitleDisplayMode(.inline)
        .tint(Theme.cyan400)
        .task { await model.load() }
    }

}
