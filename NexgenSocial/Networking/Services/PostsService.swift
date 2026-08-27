import Foundation

/// Posts: the feed, category browsing, likes, comments, and context notes.
enum PostsService {

    static func feed() async throws -> [Post] {
        try await APIClient.shared.get(APIEndpoints.Posts.feed, as: FeedResponse.self).posts
    }

    static func explore(category: String) async throws -> [Post] {
        try await APIClient.shared
            .get(APIEndpoints.Posts.explore(category: category), as: FeedResponse.self).posts
    }

    /// One person's own posts, newest first. Only the owner sees their
    /// non-public ones -- the server decides that from the token.
    static func posts(byUsername username: String) async throws -> [Post] {
        try await APIClient.shared
            .get(APIEndpoints.Posts.by(username: username), as: FeedResponse.self).posts
    }

    static func create(body: String,
                       audience: String = "PUBLIC",
                       category: String? = nil,
                       groupId: String? = nil,
                       attachments: [PickedAttachment] = []) async throws {
        var fields = ["body": body, "audience": audience]
        fields["category"] = category
        fields["groupId"] = groupId
        _ = try await APIClient.shared.upload(APIEndpoints.Posts.root,
                                              fields: fields,
                                              files: attachments.uploadFiles,
                                              as: EmptyResponse.self)
    }

    static func setLiked(_ liked: Bool, postId: String) async throws {
        if liked {
            _ = try await APIClient.shared.post(APIEndpoints.Posts.like(postId), as: EmptyResponse.self)
        } else {
            _ = try await APIClient.shared.delete(APIEndpoints.Posts.like(postId))
        }
    }

    static func comments(for postId: String) async throws -> [Comment] {
        try await APIClient.shared
            .get(APIEndpoints.Posts.comments(postId), as: CommentsResponse.self).comments
    }

    static func addComment(_ body: String, to postId: String) async throws {
        _ = try await APIClient.shared.post(APIEndpoints.Posts.comments(postId),
                                            body: ["body": body], as: CommentResponse.self)
    }

    static func contextNotes(for postId: String) async throws -> [ContextNote] {
        try await APIClient.shared
            .get(APIEndpoints.Posts.notes(postId), as: ContextNotesResponse.self).notes
    }

    static func addContextNote(_ body: String, to postId: String) async throws {
        _ = try await APIClient.shared.post(APIEndpoints.Posts.notes(postId),
                                            body: ["body": body], as: EmptyResponse.self)
    }

    static func voteContextNote(_ noteId: String, value: Int) async throws {
        _ = try await APIClient.shared.post(APIEndpoints.Posts.voteNote(noteId),
                                            body: ["value": value], as: EmptyResponse.self)
    }
}
