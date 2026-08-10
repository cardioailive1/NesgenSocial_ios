import SwiftUI

/// Syndicated headlines from the outlets' own public RSS feeds. Headline,
/// blurb, and a link out — the article itself opens at the source.
struct NewsView: View {
    @StateObject private var model = NewsViewModel()

    var body: some View {
        ZStack {
            Theme.navy950.ignoresSafeArea()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    if let errorMessage = model.errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.danger)
                            .padding(.horizontal, 14)
                    }

                    if !model.failedSources.isEmpty {
                        Text("Couldn't reach: \(model.failedSources.joined(separator: ", "))")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.slate400)
                            .padding(.horizontal, 14)
                    }

                    ForEach(model.items) { item in
                        Link(destination: URL(string: item.link) ?? URL(string: "https://example.com")!) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(item.source.uppercased())
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(Theme.cyan400)
                                Text(item.title)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .multilineTextAlignment(.leading)
                                if let description = item.description, !description.isEmpty {
                                    Text(description)
                                        .font(.system(size: 13))
                                        .foregroundStyle(Theme.slate300)
                                        .multilineTextAlignment(.leading)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .card()
                        }
                        .padding(.horizontal, 14)
                    }
                }
                .padding(.vertical, 12)
            }
            .refreshable { await model.load() }

            if model.isLoading && model.items.isEmpty {
                ProgressView().tint(Theme.cyan400)
            }
        }
        .navigationTitle("Breaking")
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load() }
    }
}

/// Newsrooms publishing on the platform, and their articles.
struct NewsroomsView: View {
    @StateObject private var model = NewsroomsViewModel()

    var body: some View {
        ZStack {
            Theme.navy950.ignoresSafeArea()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    if model.newsrooms.isEmpty {
                        Text("No newsrooms yet.")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.slate400)
                            .padding(.horizontal, 14)
                    }
                    ForEach(model.newsrooms) { newsroom in
                        NavigationLink { NewsroomDetailView(slug: newsroom.slug) } label: {
                            NewsroomCard(newsroom: newsroom)
                        }
                        .padding(.horizontal, 14)
                    }
                }
                .padding(.vertical, 12)
            }
            .refreshable { await model.load() }
        }
        .navigationTitle("Newsrooms")
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load() }
    }
}

struct NewsroomCard: View {
    let newsroom: Newsroom

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(url: newsroom.avatarUrl, seed: newsroom.slug, size: 44)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(newsroom.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                    if newsroom.verified == true {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.cyan400)
                    }
                }
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.slate400)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .card()
    }

    private var subtitle: String {
        var parts: [String] = []
        if let organization = newsroom.organization { parts.append(organization) }
        if let beat = newsroom.beat { parts.append(beat) }
        if let count = newsroom.articleCount { parts.append("\(count) articles") }
        return parts.joined(separator: " · ")
    }
}

struct NewsroomDetailView: View {
    @StateObject private var model: NewsroomDetailViewModel

    init(slug: String) {
        _model = StateObject(wrappedValue: NewsroomDetailViewModel(slug: slug))
    }

    var body: some View {
        ZStack {
            Theme.navy950.ignoresSafeArea()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if let newsroom = model.newsroom {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(newsroom.organization ?? "")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Theme.slate400)
                                if let description = newsroom.description {
                                    Text(description)
                                        .font(.system(size: 13))
                                        .foregroundStyle(Theme.slate300)
                                }
                            }
                            Spacer(minLength: 0)
                            Button(model.isFollowing ? "Following" : "Follow") {
                                Task { await model.toggleFollow(newsroom) }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(model.isFollowing ? Theme.navy800 : Theme.cyan400)
                            .font(.system(size: 13))
                        }
                        .padding(.horizontal, 14)

                        SectionHeader("Articles")
                        ForEach(newsroom.articles ?? []) { article in
                            ArticleCard(article: article)
                                .padding(.horizontal, 14)
                        }
                    }
                }
                .padding(.vertical, 12)
            }
            .refreshable { await model.load() }
        }
        .navigationTitle(model.newsroom?.name ?? "Newsroom")
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load() }
    }
}

struct ArticleCard: View {
    let article: NewsArticle

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if article.isBreaking == true {
                Text("BREAKING")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.navy950)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Theme.danger)
                    .clipShape(Capsule())
            }
            Text(article.headline)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
            if let standfirst = article.standfirst {
                Text(standfirst)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.slate400)
            }
            if let media = article.media, !media.isEmpty {
                MediaCarousel(items: media)
            }
            if let body = article.body {
                Text(body)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.slate300)
            }
            if let byline = article.byline {
                Text("By \(byline)")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.slate400)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .card()
    }
}
