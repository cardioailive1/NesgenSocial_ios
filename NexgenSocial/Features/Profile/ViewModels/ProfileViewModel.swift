import Foundation

/// Backs the signed-in person's own profile: their counts and their posts.
///
/// Counts come from `/api/users/:username` rather than the auth payload
/// because they're computed per request -- the cached `currentUser` goes
/// stale the moment somebody follows you.
@MainActor
final class ProfileViewModel: ObservableObject {
    @Published var stats: ProfileStats?
    @Published var posts: [Post] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    var postCount: Int { posts.count }

    func load(username: String) async {
        guard !username.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        // The two calls are independent: a failure to load counts shouldn't
        // blank the grid, and vice versa.
        async let profile = ProfileService.profile(username)
        async let mine = PostsService.posts(byUsername: username)

        do { stats = (try await profile).stats } catch { errorMessage = error.localizedDescription }
        do { posts = try await mine } catch { errorMessage = error.localizedDescription }
    }
}
