import Foundation

@MainActor
final class PoliticalViewModel: ObservableObject {
    @Published private(set) var pages: [PoliticalPage] = []
    @Published var typeFilter = ""

    func load() async {
        pages = (try? await PoliticalService.pages(type: typeFilter)) ?? []
    }
}

@MainActor
final class PoliticalPageViewModel: ObservableObject {
    @Published private(set) var posts: [PoliticalPost] = []
    @Published private(set) var isFollowing = false

    private let page: PoliticalPage

    init(page: PoliticalPage) { self.page = page }

    func load() async {
        posts = (try? await PoliticalService.posts(on: page.id)) ?? []
        isFollowing = page.followedByViewer ?? false
    }

    func toggleFollow() async {
        try? await PoliticalService.setFollowing(!isFollowing, pageId: page.id)
        isFollowing.toggle()
    }
}
