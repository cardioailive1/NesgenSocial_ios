import Foundation

enum ReelsService {

    static func discover(hashtag: String = "") async throws -> [Reel] {
        try await APIClient.shared.get(APIEndpoints.Reels.discover(hashtag: hashtag),
                                       as: ReelsResponse.self).reels
    }

    static func trendingHashtags() async throws -> [TrendingHashtag] {
        try await APIClient.shared.get(APIEndpoints.Reels.trendingHashtags,
                                       as: TrendingHashtagsResponse.self).trending
    }

    /// The server reads `video` and `thumbnail` as separate multipart fields,
    /// not the shared `media` field posts use, so this can't reuse
    /// `uploadFiles`.
    static func create(caption: String,
                       durationSec: Double,
                       video: Data,
                       thumbnail: Data?) async throws -> Reel {
        var files: [(name: String, filename: String, mimeType: String, data: Data)] = [
            (name: "video", filename: "reel-\(UUID().uuidString).mov", mimeType: "video/quicktime", data: video)
        ]
        if let thumbnail {
            files.append((name: "thumbnail", filename: "thumb-\(UUID().uuidString).jpg",
                          mimeType: "image/jpeg", data: thumbnail))
        }
        return try await APIClient.shared.upload(APIEndpoints.Reels.root,
                                                 fields: ["caption": caption,
                                                          "durationSec": String(format: "%.0f", durationSec)],
                                                 files: files,
                                                 as: ReelResponse.self).reel
    }

    static func setLiked(_ liked: Bool, reelId: String) async throws {
        if liked {
            _ = try await APIClient.shared.post(APIEndpoints.Reels.like(reelId), as: EmptyResponse.self)
        } else {
            _ = try await APIClient.shared.delete(APIEndpoints.Reels.like(reelId))
        }
    }

    /// Reel comments are their own table server-side, but they come back in
    /// the same shape post comments do, so they decode into `Comment` too.
    static func comments(for reelId: String) async throws -> [Comment] {
        try await APIClient.shared.get(APIEndpoints.Reels.comments(reelId),
                                       as: CommentsResponse.self).comments
    }

    static func addComment(_ body: String, to reelId: String) async throws -> Comment {
        try await APIClient.shared.post(APIEndpoints.Reels.comments(reelId),
                                        body: ["body": body],
                                        as: CommentResponse.self).comment
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
