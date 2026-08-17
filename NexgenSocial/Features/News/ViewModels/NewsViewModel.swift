import Foundation

@MainActor
final class NewsViewModel: ObservableObject {
    @Published private(set) var items: [NewsItem] = []
    @Published private(set) var failedSources: [String] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let response = try await NewsService.breaking()
            items = response.items
            failedSources = response.failedSources ?? []
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

@MainActor
final class NewsroomsViewModel: ObservableObject {
    @Published private(set) var newsrooms: [Newsroom] = []
    @Published var errorMessage: String?

    func load() async {
        do {
            newsrooms = try await NewsService.newsrooms()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

@MainActor
final class NewsroomDetailViewModel: ObservableObject {
    @Published private(set) var newsroom: Newsroom?
    @Published private(set) var isFollowing = false
    @Published var errorMessage: String?

    private let slug: String

    init(slug: String) { self.slug = slug }

    func load() async {
        do {
            let loaded = try await NewsService.newsroom(slug: slug)
            newsroom = loaded
            isFollowing = loaded.followedByViewer ?? false
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
