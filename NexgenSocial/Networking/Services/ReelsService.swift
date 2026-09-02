import Foundation

enum ReelsService {

    static func discover() async throws -> [Reel] {
        try await APIClient.shared.get(APIEndpoints.Reels.discover, as: ReelsResponse.self).reels
    }

    static func setLiked(_ liked: Bool, reelId: String) async throws {
        if liked {
            _ = try await APIClient.shared.post(APIEndpoints.Reels.like(reelId), as: EmptyResponse.self)
        } else {
            _ = try await APIClient.shared.delete(APIEndpoints.Reels.like(reelId))
        }
    }

    /// Watch time drives ranking on the server, so it's reported per reel
    /// rather than only for reels that were watched to the end.
    static func reportView(reelId: String, watchedSec: Double, completed: Bool) async throws {
        _ = try await APIClient.shared.post(APIEndpoints.Reels.view(reelId),
                                            body: ["watchedSec": watchedSec, "completed": completed],
                                            as: EmptyResponse.self,
                                            // Fires on every reel watched;
                                            // clearing the cache each time
                                            // would leave nothing cached.
                                            invalidates: false)
    }
}
