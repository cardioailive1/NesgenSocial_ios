import SwiftUI
import PhotosUI

/// Syndicated headlines from the outlets' own public RSS feeds. Headline,
/// blurb, and a link out — the article itself opens at the source.
struct NewsView: View {
    @StateObject private var model = NewsViewModel()

    var body: some View {
        ZStack {
            Theme.navy950.ignoresSafeArea()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ErrorBanner(message: model.errorMessage)

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
            .pullToRefresh { await model.load() }

            if model.isLoading && model.items.isEmpty {
                ProgressView().tint(Theme.cyan400)
            }
        }
        .navigationTitle("Breaking")
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
    @EnvironmentObject private var session: AuthSession

    /// Cleared after each batch is handed over, so picking the same photo
    /// twice in a row still registers as a change.
    @State private var galleryPicks: [PhotosPickerItem] = []

    init(slug: String) {
        _model = StateObject(wrappedValue: NewsroomDetailViewModel(slug: slug))
    }

    var body: some View {
        ZStack {
            Theme.navy950.ignoresSafeArea()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ErrorBanner(message: model.errorMessage)
                        .padding(.horizontal, 14)

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

                        if let media = newsroom.media, !media.isEmpty {
                            SectionHeader("Gallery")
                            MediaCarousel(items: media)
                                .padding(.horizontal, 14)
                        }

                        if newsroom.owner?.username == session.currentUser?.username {
                            PhotosPicker(selection: $galleryPicks, maxSelectionCount: 10,
                                         matching: .any(of: [.images, .videos])) {
                                Label("Add to gallery", systemImage: "photo.on.rectangle.angled")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Theme.cyan300)
                            }
                            .padding(.horizontal, 14)
                        }

                        SectionHeader("Articles")
                        ForEach(newsroom.articles ?? []) { article in
                            ArticleCard(article: article,
                                        canEdit: newsroom.owner?.username
                                            == session.currentUser?.username) {
                                await model.load()
                            }
                            .padding(.horizontal, 14)
                        }
                    }
                }
                .padding(.vertical, 12)
            }
            .pullToRefresh { await model.load() }
        }
        .navigationTitle(model.newsroom?.name ?? "Newsroom")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: galleryPicks) { _, picked in
            guard !picked.isEmpty else { return }
            galleryPicks = []
            Task { await model.addMedia(picked) }
        }
        .task { await model.load() }
    }
}

struct ArticleCard: View {
    let article: NewsArticle
    /// Set only where the viewer owns the newsroom the story came from. The
    /// server checks ownership too, so this is about not showing a menu that
    /// can only 404.
    var canEdit = false
    /// Reload the list the card came from after an edit or a delete.
    var onChanged: (() async -> Void)?

    /// Stories run long; the card shows the top of one and opens on demand,
    /// as "Read full story" does on the web.
    @State private var expanded = false
    @State private var editing = false
    @State private var confirmingDelete = false
    @State private var deleteFailed: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                if article.isBreaking == true {
                    Text("BREAKING")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Theme.navy950)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Theme.danger)
                        .clipShape(Capsule())
                }
                Spacer(minLength: 0)
                if canEdit {
                    Menu {
                        Button("Edit story", systemImage: "pencil") { editing = true }
                        Button("Delete story", systemImage: "trash", role: .destructive) {
                            confirmingDelete = true
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundStyle(Theme.slate400)
                            .padding(4)
                    }
                }
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
            if let body = article.body, !body.isEmpty {
                Text(body)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.slate300)
                    .lineLimit(expanded ? nil : 3)
                Button(expanded ? "Show less" : "Read full story") { expanded.toggle() }
                    .font(.system(size: 12))
                    .tint(Theme.cyan400)
            }
            Text(footnote)
                .font(.system(size: 11))
                .foregroundStyle(Theme.slate400)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .card()
        .sheet(isPresented: $editing) {
            EditArticleView(article: article) { await onChanged?() }
        }
        .confirmationDialog("Delete this story?", isPresented: $confirmingDelete,
                            titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                Task {
                    do {
                        try await NewsService.deleteArticle(article.id)
                        await onChanged?()
                    } catch {
                        deleteFailed = error.localizedDescription
                    }
                }
            }
        } message: {
            Text("It disappears from the coverage feed and from your newsroom.")
        }
        .alert("Couldn't delete the story",
               isPresented: Binding(get: { deleteFailed != nil },
                                    set: { if !$0 { deleteFailed = nil } })) {
            Button("OK", role: .cancel) { deleteFailed = nil }
        } message: {
            Text(deleteFailed ?? "")
        }
    }

    private var footnote: String {
        var parts: [String] = []
        if let newsroom = article.newsroom?.name { parts.append(newsroom) }
        if let byline = article.byline { parts.append("By \(byline)") }
        if let published = article.publishedAt { parts.append(Self.day(published)) }
        if article.correctedAt != nil { parts.append("Corrected") }
        return parts.joined(separator: " · ")
    }

    private static func day(_ iso: String) -> String {
        guard let date = ISO8601DateFormatter().date(from: iso) else { return "" }
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}

/// Editing a published story. Media isn't editable: the server's PATCH takes
/// text fields only, and changing the body records a public correction.
struct EditArticleView: View {
    @Environment(\.dismiss) private var dismiss
    let article: NewsArticle
    let onSaved: () async -> Void

    @StateObject private var model = EditArticleViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.navy950.ignoresSafeArea()
                Form {
                    SwiftUI.Section {
                        TextField("Headline", text: $model.headline)
                        TextField("Standfirst / summary (optional)", text: $model.standfirst)
                        TextField("Story body", text: $model.body, axis: .vertical)
                            .lineLimit(6...14)
                        TextField("Byline (optional)", text: $model.byline)
                        Toggle("Mark as breaking", isOn: $model.isBreaking)
                    } footer: {
                        Text("Changing the body marks the story as corrected, and that label is shown to readers.")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.slate400)
                    }
                    .listRowBackground(Theme.navy900)

                    if model.errorMessage != nil {
                        ErrorBanner(message: model.errorMessage)
                            .listRowBackground(Color.clear)
                    }
                }
                .scrollContentBackground(.hidden)
                .foregroundStyle(.white)
                .tint(Theme.cyan400)
            }
            .navigationTitle("Edit story")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.tint(Theme.slate400)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(model.isSaving ? "Saving…" : "Save") {
                        Task {
                            guard await model.save(articleId: article.id) else { return }
                            dismiss()
                            await onSaved()
                        }
                    }
                    .disabled(!model.canSubmit)
                    .tint(Theme.cyan400)
                }
            }
            .onAppear { model.fill(from: article) }
        }
    }
}
