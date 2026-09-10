import Foundation
import SwiftUI
import PhotosUI

@MainActor
final class NewsViewModel: ObservableObject, LoadingViewModel {
    @Published private(set) var items: [NewsItem] = []
    @Published private(set) var failedSources: [String] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    func load() async {
        isLoading = true
        defer { isLoading = false }
        await attempt {
            let response = try await NewsService.breaking()
            items = response.items
            failedSources = response.failedSources ?? []
        }
    }
}

/// Backs all three Media Coverage sections: the stories, the newsrooms, and
/// the publishing tools for the ones you own.
@MainActor
final class MediaCoverageViewModel: ObservableObject, LoadingViewModel {
    @Published private(set) var newsrooms: [Newsroom] = []
    @Published private(set) var articles: [NewsArticle] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    /// The newsrooms you can publish from.
    func mine(username: String?) -> [Newsroom] {
        guard let username else { return [] }
        return newsrooms.filter { $0.owner?.username == username }
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        await attempt {
            async let stories = NewsService.latestArticles()
            async let rooms = NewsService.newsrooms()
            articles = try await stories
            newsrooms = try await rooms
        }
    }

    func toggleFollow(_ newsroom: Newsroom) async {
        let following = newsroom.followedByViewer ?? false
        do {
            try await NewsService.setFollowing(!following, newsroomId: newsroom.id)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func goLive(as newsroom: Newsroom) async -> Livestream? {
        do {
            return try await LivestreamsService.start(title: "\(newsroom.name) live",
                                                      newsroomId: newsroom.id)
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
}

@MainActor
final class NewNewsroomViewModel: ObservableObject, LoadingViewModel {
    @Published var name = ""
    @Published var organization = ""
    @Published var details = ""
    @Published var beat = ""
    @Published var region = ""
    @Published var websiteUrl = ""
    @Published var logo: [PickedAttachment] = []
    @Published var cover: [PickedAttachment] = []
    @Published var media: [PickedAttachment] = []
    @Published private(set) var isSaving = false
    @Published var errorMessage: String?

    var canSubmit: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && !organization.trimmingCharacters(in: .whitespaces).isEmpty
            && !isSaving
    }

    func create() async -> Newsroom? {
        isSaving = true
        defer { isSaving = false }
        do {
            return try await NewsService.createNewsroom(
                fields: ["name": name, "organization": organization, "description": details,
                         "beat": beat, "region": region, "websiteUrl": websiteUrl],
                logo: logo.first, cover: cover.first, media: media)
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
}

@MainActor
final class PublishArticleViewModel: ObservableObject, LoadingViewModel {
    @Published var newsroomId = ""
    @Published var headline = ""
    @Published var standfirst = ""
    @Published var body = ""
    @Published var byline = ""
    @Published var isBreaking = false
    @Published var media: [PickedAttachment] = []
    @Published private(set) var isPublishing = false
    @Published var errorMessage: String?

    var canSubmit: Bool {
        !newsroomId.isEmpty
            && !headline.trimmingCharacters(in: .whitespaces).isEmpty
            && !body.trimmingCharacters(in: .whitespaces).isEmpty
            && !isPublishing
    }

    func publish() async -> Bool {
        isPublishing = true
        defer { isPublishing = false }
        do {
            _ = try await NewsService.publishArticle(in: newsroomId,
                                                     headline: headline,
                                                     standfirst: standfirst,
                                                     body: body,
                                                     byline: byline,
                                                     isBreaking: isBreaking,
                                                     media: media)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}

@MainActor
final class NewsroomDetailViewModel: ObservableObject, LoadingViewModel {
    @Published private(set) var newsroom: Newsroom?
    @Published private(set) var isFollowing = false
    @Published var errorMessage: String?

    private let slug: String

    init(slug: String) { self.slug = slug }

    func load() async {
        await attempt {
            let loaded = try await NewsService.newsroom(slug: slug)
            newsroom = loaded
            isFollowing = loaded.followedByViewer ?? false
        }
    }

    /// Owner-only. The response carries the whole gallery back, so the
    /// section redraws without another fetch of the newsroom.
    func addMedia(_ items: [PhotosPickerItem]) async {
        guard let id = newsroom?.id else { return }
        let picked = await AttachmentLoader.load(items)
        guard !picked.isEmpty else { return }
        do {
            newsroom?.media = try await NewsService.addNewsroomMedia(picked, to: id)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleFollow(_ newsroom: Newsroom) async {
        isFollowing.toggle()
        do {
            try await NewsService.setFollowing(isFollowing, newsroomId: newsroom.id)
        } catch {
            isFollowing.toggle()
            errorMessage = error.localizedDescription
        }
    }
}

@MainActor
final class EditArticleViewModel: ObservableObject {
    @Published var headline = ""
    @Published var standfirst = ""
    @Published var body = ""
    @Published var byline = ""
    @Published var isBreaking = false
    @Published private(set) var isSaving = false
    @Published var errorMessage: String?

    private var filled = false

    var canSubmit: Bool {
        !isSaving
            && !headline.trimmingCharacters(in: .whitespaces).isEmpty
            && !body.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// `onAppear` fires again when the sheet comes back from the background,
    /// so the form is seeded once and never overwrites what's being typed.
    func fill(from article: NewsArticle) {
        guard !filled else { return }
        filled = true
        headline = article.headline
        standfirst = article.standfirst ?? ""
        body = article.body ?? ""
        byline = article.byline ?? ""
        isBreaking = article.isBreaking ?? false
    }

    func save(articleId: String) async -> Bool {
        isSaving = true
        defer { isSaving = false }
        do {
            _ = try await NewsService.updateArticle(articleId, fields: [
                "headline": headline.trimmingCharacters(in: .whitespaces),
                "standfirst": standfirst.trimmingCharacters(in: .whitespaces),
                "body": body.trimmingCharacters(in: .whitespaces),
                "byline": byline.trimmingCharacters(in: .whitespaces),
                "isBreaking": isBreaking,
            ])
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
