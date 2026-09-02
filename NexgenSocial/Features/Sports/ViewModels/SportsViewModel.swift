import Foundation

@MainActor
final class SportsViewModel: ObservableObject, LoadingViewModel {
    @Published private(set) var leagues: [SportsLeague] = []
    @Published private(set) var live: [SportsEvent] = []
    @Published private(set) var scores: SportsScoresResponse?
    /// Empty until the league list arrives: the server only accepts keys it
    /// publishes from /api/sports/leagues, so any hardcoded default is one
    /// backend league rename away from an "Unknown league" error on first load.
    @Published var selectedLeague = ""
    @Published var errorMessage: String?

    /// Community talk is just the SPORTS category of the normal post feed —
    /// same store the web screen reads and writes.
    @Published private(set) var posts: [Post] = []
    @Published var draft = ""
    @Published var attachments: [PickedAttachment] = []
    @Published private(set) var isPosting = false

    private static let category = "SPORTS"

    var canPost: Bool { !draft.isEmpty || !attachments.isEmpty }

    func loadPosts() async {
        do {
            posts = try await PostsService.explore(category: Self.category)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func submit() async {
        guard canPost, !isPosting else { return }
        isPosting = true
        defer { isPosting = false }
        do {
            try await PostsService.create(body: draft,
                                          category: Self.category,
                                          attachments: attachments)
            draft = ""
            attachments = []
            await loadPosts()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleLike(_ post: Post) async {
        guard let index = posts.firstIndex(where: { $0.id == post.id }) else { return }
        posts[index].toggleLikeLocally()
        do {
            try await PostsService.setLiked(posts[index].isLiked, postId: post.id)
        } catch {
            posts[index].toggleLikeLocally()
        }
    }

    func loadAll() async {
        async let loadedLeagues = SportsService.leagues()
        async let loadedLive = SportsService.live()
        do {
            leagues = try await loadedLeagues
            live = try await loadedLive
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        if !leagues.contains(where: { $0.key == selectedLeague }) {
            selectedLeague = leagues.first?.key ?? ""
        }
        // No loadScores() here: assigning selectedLeague fires the view's
        // onChange, which loads them. Calling it too would double the request.
    }

    func loadScores() async {
        guard !selectedLeague.isEmpty else { return }
        await attempt {
            scores = try await SportsService.scores(league: selectedLeague)
        }
    }
}
