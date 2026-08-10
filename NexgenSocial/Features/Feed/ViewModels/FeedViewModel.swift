import Foundation

@MainActor
final class FeedViewModel: ObservableObject {
    @Published var posts: [Post] = []
    @Published var sponsored: [Ad] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            posts = try await PostsService.feed()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }

        // Ads failing is never worth blocking the feed over.
        sponsored = (try? await AdsService.serve()) ?? []
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
