import Foundation

enum PoliticalService {

    static func pages(type: String) async throws -> [PoliticalPage] {
        let path = type.isEmpty
            ? APIEndpoints.Political.pages
            : "\(APIEndpoints.Political.pages)?type=\(type.urlQueryEscaped)"
        return try await APIClient.shared.get(path, as: PoliticalPagesResponse.self).pages
    }

    static func posts(on pageId: String) async throws -> [PoliticalPost] {
        try await APIClient.shared
            .get(APIEndpoints.Political.posts(pageId), as: PoliticalPostsResponse.self).posts
    }

    /// Public and unauthenticated on purpose: the archive is the disclosure
    /// record, so it stays readable whether or not you're signed in.
    static func archive(query: String = "") async throws -> [PoliticalAd] {
        let path = query.isEmpty
            ? APIEndpoints.Political.archive
            : "\(APIEndpoints.Political.archive)?q=\(query.urlQueryEscaped)"
        return try await APIClient.shared.get(path, as: PoliticalArchiveResponse.self).ads
    }

    /// `organization` is who's responsible for the page. The server rejects a
    /// page without one, which is what keeps anonymous political pages off it.
    static func createPage(fields: [String: String],
                           avatar: PickedAttachment?,
                           media: [PickedAttachment] = []) async throws -> PoliticalPage {
        let files = (avatar.map { [(name: "avatar", filename: $0.filename,
                                    mimeType: $0.mimeType, data: $0.data)] } ?? [])
            + media.uploadFiles
        return try await APIClient.shared.upload(APIEndpoints.Political.pages,
                                                 fields: fields,
                                                 files: files,
                                                 as: PoliticalPageResponse.self).page
    }

    static func createPost(on pageId: String, body: String,
                           attachments: [PickedAttachment]) async throws {
        _ = try await APIClient.shared.upload(APIEndpoints.Political.posts(pageId),
                                              fields: ["body": body],
                                              files: attachments.uploadFiles,
                                              as: EmptyResponse.self)
    }

    /// Runs an ad from a page you own. `paidForBy` is legally required and
    /// the server rejects a blank one, so the form requires it too.
    static func createAd(pageId: String,
                         headline: String,
                         body: String,
                         paidForBy: String,
                         targetUrl: String,
                         spendCents: Int,
                         region: String,
                         media: PickedAttachment?) async throws -> PoliticalAd {
        var fields = ["pageId": pageId, "headline": headline, "body": body,
                      "paidForBy": paidForBy, "spendCents": String(spendCents)]
        if !targetUrl.isEmpty { fields["targetUrl"] = targetUrl }
        if !region.isEmpty { fields["region"] = region }
        let files = media.map { [(name: "media", filename: $0.filename,
                                  mimeType: $0.mimeType, data: $0.data)] } ?? []
        return try await APIClient.shared.upload(APIEndpoints.Political.ads,
                                                 fields: fields,
                                                 files: files,
                                                 as: PoliticalAdResponse.self).ad
    }

    static func setFollowing(_ following: Bool, pageId: String) async throws {
        if following {
            _ = try await APIClient.shared.post(APIEndpoints.Political.follow(pageId),
                                                as: EmptyResponse.self)
        } else {
            _ = try await APIClient.shared.delete(APIEndpoints.Political.follow(pageId))
        }
    }
}
