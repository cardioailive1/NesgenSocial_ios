import Foundation

@MainActor
final class ReelsViewModel: ObservableObject, LoadingViewModel {
    @Published var reels: [Reel] = []
    @Published private(set) var trending: [TrendingHashtag] = []
    /// Empty means the ranked "For you" feed, which is what the server
    /// returns when no hashtag is sent.
    @Published private(set) var activeTag = ""
    @Published var isLoading = false
    @Published var errorMessage: String?

    func load() async {
        isLoading = true
        defer { isLoading = false }
        await attempt {
            reels = try await ReelsService.discover(hashtag: activeTag)
        }
        // A missing tag rail is worth less than a broken screen, so this
        // failing never surfaces as an error.
        if trending.isEmpty {
            trending = (try? await ReelsService.trendingHashtags()) ?? []
        }
    }

    func select(tag: String) async {
        guard tag != activeTag else { return }
        activeTag = tag
        reels = []
        await load()
    }

    /// Analytics only: a dropped view report is not worth telling anyone about.
    func reportView(_ reel: Reel, watchedSec: Double, completed: Bool) async {
        try? await ReelsService.reportView(reelId: reel.id,
                                           watchedSec: watchedSec,
                                           completed: completed)
    }

    /// The comment sheet posts through the service directly; this keeps the
    /// count under the reel honest without refetching the whole feed.
    func countNewComment(on reel: Reel) {
        guard let index = reels.firstIndex(where: { $0.id == reel.id }) else { return }
        reels[index].commentCount = (reels[index].commentCount ?? 0) + 1
    }

    func toggleLike(_ reel: Reel) async {
        guard let index = reels.firstIndex(where: { $0.id == reel.id }) else { return }
        reels[index].toggleLikeLocally()
        do {
            try await ReelsService.setLiked(reels[index].isLiked, reelId: reel.id)
        } catch {
            reels[index].toggleLikeLocally()
        }
    }
}
