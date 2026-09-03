import Foundation

@MainActor
final class PoliticalViewModel: ObservableObject, LoadingViewModel {
    @Published private(set) var pages: [PoliticalPage] = []
    @Published var typeFilter = ""
    @Published var errorMessage: String?

    func load() async {
        await attempt {
            pages = try await PoliticalService.pages(type: typeFilter)
        }
    }
}

@MainActor
final class PoliticalArchiveViewModel: ObservableObject, LoadingViewModel {
    @Published private(set) var ads: [PoliticalAd] = []
    @Published var query = ""
    @Published var errorMessage: String?

    func load() async {
        await attempt {
            ads = try await PoliticalService.archive(query: query)
        }
    }
}

@MainActor
final class CreatePoliticalPageViewModel: ObservableObject, LoadingViewModel {
    @Published var type = "CANDIDATE"
    @Published var name = ""
    @Published var organization = ""
    @Published var pageDescription = ""
    @Published var websiteUrl = ""
    @Published var region = ""
    @Published var avatar: [PickedAttachment] = []
    @Published var media: [PickedAttachment] = []
    @Published private(set) var isSaving = false
    @Published var errorMessage: String?

    /// Name and organization are the server's own requirements — a political
    /// page with no responsible organization is rejected there too.
    var canSave: Bool { !name.isEmpty && !organization.isEmpty }

    func save() async -> Bool {
        guard canSave, !isSaving else { return false }
        isSaving = true
        defer { isSaving = false }
        do {
            _ = try await PoliticalService.createPage(
                fields: ["type": type, "name": name, "organization": organization,
                         "description": pageDescription, "websiteUrl": websiteUrl,
                         "region": region],
                avatar: avatar.first,
                media: media)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}

@MainActor
final class PoliticalPageViewModel: ObservableObject, LoadingViewModel {
    @Published private(set) var posts: [PoliticalPost] = []
    @Published private(set) var isFollowing = false
    @Published var errorMessage: String?
    @Published var draft = ""
    @Published var attachments: [PickedAttachment] = []
    @Published private(set) var isPosting = false

    private let page: PoliticalPage

    init(page: PoliticalPage) { self.page = page }

    var canPost: Bool { !draft.isEmpty || !attachments.isEmpty }

    func submit() async {
        guard canPost, !isPosting else { return }
        isPosting = true
        defer { isPosting = false }
        do {
            try await PoliticalService.createPost(on: page.id, body: draft,
                                                  attachments: attachments)
            draft = ""
            attachments = []
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func load() async {
        isFollowing = page.followedByViewer ?? false
        do {
            posts = try await PoliticalService.posts(on: page.id)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Flips first and puts it back if the call fails, like the like button:
    /// a follow that waits for the round trip reads as a dead tap.
    func toggleFollow() async {
        isFollowing.toggle()
        do {
            try await PoliticalService.setFollowing(isFollowing, pageId: page.id)
        } catch {
            isFollowing.toggle()
            errorMessage = error.localizedDescription
        }
    }
}

@MainActor
final class RunPoliticalAdViewModel: ObservableObject {
    @Published var headline = ""
    @Published var body = ""
    @Published var paidForBy = ""
    @Published var targetUrl = ""
    @Published var spend = ""
    @Published var region = ""
    @Published var media: [PickedAttachment] = []
    @Published private(set) var isSaving = false
    @Published var errorMessage: String?

    /// The server's own three requirements. "Paid for by" is a legal
    /// disclosure, not a nicety, so it is required here as well.
    var canSave: Bool {
        [headline, body, paidForBy].allSatisfy {
            !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    /// Typed in whole currency; the API stores cents.
    private var spendCents: Int { Int((Double(spend) ?? 0) * 100) }

    func save(pageId: String) async -> Bool {
        guard canSave, !isSaving else { return false }
        isSaving = true
        defer { isSaving = false }
        do {
            _ = try await PoliticalService.createAd(pageId: pageId,
                                                    headline: headline,
                                                    body: body,
                                                    paidForBy: paidForBy,
                                                    targetUrl: targetUrl,
                                                    spendCents: spendCents,
                                                    region: region,
                                                    media: media.first)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
