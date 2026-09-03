import Foundation

@MainActor
final class FeedViewModel: ObservableObject, LoadingViewModel {
    @Published var posts: [Post] = []
    @Published var sponsored: [Ad] = []
    @Published var weights = FeedWeights.default
    @Published var isLoading = false
    @Published var errorMessage: String?

    func load() async {
        isLoading = true
        defer { isLoading = false }
        await attempt {
            let response = try await PostsService.feed()
            posts = response.posts
            if let served = response.feedWeights { weights = served }
        }

        // Ads failing is never worth blocking the feed over.
        sponsored = (try? await AdsService.serve()) ?? []
    }

    /// Save, then reload: the ranking only changes on the server's next pass.
    func saveWeights() async {
        await attempt {
            weights = try await PostsService.setFeedWeights(weights)
        }
        await load()
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

    func trackAd(_ type: String, ad: Ad) async {
        await AdsService.track(type, adId: ad.id)
    }
}
