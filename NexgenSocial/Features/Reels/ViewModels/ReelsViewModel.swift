import Foundation

@MainActor
final class ReelsViewModel: ObservableObject {
    @Published var reels: [Reel] = []
    @Published var isLoading = false

    func load() async {
        isLoading = true
        defer { isLoading = false }
        reels = (try? await ReelsService.discover()) ?? []
    }

    func reportView(_ reel: Reel, watchedSec: Double, completed: Bool) async {
        try? await ReelsService.reportView(reelId: reel.id,
                                           watchedSec: watchedSec,
                                           completed: completed)
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
