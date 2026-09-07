import Foundation

/// Backs a profile, the viewer's own or someone else's: the counts, the
/// posts, the reels, and — for someone else — the viewer's relationship to
/// them.
///
/// Counts come from `/api/users/:username` rather than the auth payload
/// because they're computed per request -- the cached `currentUser` goes
/// stale the moment somebody follows you.
@MainActor
final class ProfileViewModel: ObservableObject {
    @Published var user: User?
    @Published var stats: ProfileStats?
    /// The viewer's relationship to this person. The server fills it only
    /// when a signed-in viewer is looking at somebody else, so it stays nil
    /// on your own profile — which is exactly when the buttons don't apply.
    @Published var viewerContext: ViewerContext?
    @Published var posts: [Post] = []
    @Published var reels: [Reel] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    /// Set when the profile itself couldn't be read -- a 404 on a username
    /// that doesn't exist, say. Kept apart from `errorMessage` so the screen
    /// can say "no such profile" instead of drawing an empty grid that reads
    /// as "posted nothing".
    @Published var loadFailed = false

    var postCount: Int { posts.count }

    var isFollowing: Bool { viewerContext?.isFollowing ?? false }
    var friendStatus: String { viewerContext?.friendStatus ?? "NONE" }

    func load(username: String) async {
        guard !username.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        // Independent on purpose: a failure to load counts shouldn't blank
        // the grid, and vice versa. Reels are the profile's second tab and
        // failing to load them is never worth an error over the whole screen.
        async let profile = ProfileService.profile(username)
        async let mine = PostsService.posts(byUsername: username)

        do {
            let response = try await profile
            user = response.user
            stats = response.stats
            viewerContext = response.viewerContext
            loadFailed = false
        } catch {
            errorMessage = error.localizedDescription
            loadFailed = true
        }
        do { posts = try await mine } catch { errorMessage = error.localizedDescription }

        reels = (try? await ReelsService.reels(by: username)) ?? []
    }

    /// Flips first and puts it back if the call fails, like the like button:
    /// a follow that waits for the round trip reads as a dead tap.
    func toggleFollow(username: String) async {
        let wasFollowing = isFollowing
        setFollowing(!wasFollowing, adjustingCount: true)
        do {
            try await DiscoveryService.setFollowing(!wasFollowing, username: username)
        } catch {
            setFollowing(wasFollowing, adjustingCount: true)
            errorMessage = error.localizedDescription
        }
    }

    /// Friend requests have no undo and no optimistic state worth faking:
    /// the server decides, and the button reads "Requested" once it agrees.
    func sendFriendRequest(username: String) async {
        do {
            try await FriendsService.sendRequest(to: username)
            viewerContext = ViewerContext(isFollowing: isFollowing, friendStatus: "PENDING")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Flips locally, then puts it back if the server refuses -- the same
    /// optimistic like the feed does.
    func toggleLike(_ post: Post) async {
        guard let index = posts.firstIndex(where: { $0.id == post.id }) else { return }
        posts[index].toggleLikeLocally()
        do {
            try await PostsService.setLiked(posts[index].isLiked, postId: post.id)
        } catch {
            posts[index].toggleLikeLocally()
        }
    }

    func removeDeletedReel(_ reelId: String) {
        reels.removeAll { $0.id == reelId }
    }

    private func setFollowing(_ following: Bool, adjustingCount: Bool) {
        viewerContext = ViewerContext(isFollowing: following, friendStatus: friendStatus)
        guard adjustingCount, var counts = stats else { return }
        counts.followerCount = max(0, (counts.followerCount ?? 0) + (following ? 1 : -1))
        stats = counts
    }
}
