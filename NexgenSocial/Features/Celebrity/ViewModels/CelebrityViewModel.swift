import Foundation

@MainActor
final class CelebrityViewModel: ObservableObject, LoadingViewModel {
    @Published private(set) var posts: [Post] = []
    @Published var draft = ""
    @Published var attachments: [PickedAttachment] = []
    @Published private(set) var isPosting = false
    @Published var errorMessage: String?

    private static let category = "CELEBRITY"

    var canPost: Bool { !draft.isEmpty || !attachments.isEmpty }

    func load() async {
        await attempt {
            posts = try await PostsService.explore(category: Self.category)
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
            await load()
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
}
