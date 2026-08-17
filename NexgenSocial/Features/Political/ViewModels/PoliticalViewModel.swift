import Foundation

@MainActor
final class PoliticalViewModel: ObservableObject {
    @Published private(set) var pages: [PoliticalPage] = []
    @Published var typeFilter = ""
    @Published var errorMessage: String?

    func load() async {
        do {
            pages = try await PoliticalService.pages(type: typeFilter)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

@MainActor
final class PoliticalPageViewModel: ObservableObject {
    @Published private(set) var posts: [PoliticalPost] = []
    @Published private(set) var isFollowing = false
    @Published var errorMessage: String?

    private let page: PoliticalPage

    init(page: PoliticalPage) { self.page = page }

    func load() async {
        isFollowing = page.followedByViewer ?? false
        do {
            posts = try await PoliticalService.posts(on: page.id)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Flips first and puts it back if the call fails, like the like button:
    /// a follow that waits for the round trip reads as a dead tap.
    func toggleFollow() async {
        isFollowing.toggle()
        do {
            try await PoliticalService.setFollowing(isFollowing, pageId: page.id)
        } catch {
            isFollowing.toggle()
            errorMessage = error.localizedDescription
        }
    }
}
