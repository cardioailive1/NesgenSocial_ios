import Foundation
import SwiftUI
import PhotosUI

@MainActor
final class ComposerViewModel: ObservableObject {
    @Published var text = ""
    @Published var attachments: [PickedAttachment] = []
    @Published var audience = Audience.public.rawValue
    @Published private(set) var isPosting = false
    @Published var errorMessage: String?

    enum Audience: String, CaseIterable {
        case `public` = "PUBLIC"
        case followers = "FOLLOWERS"
        case friends = "FRIENDS"

        var title: String {
            switch self {
            case .public:    return "Everyone"
            case .followers: return "Followers"
            case .friends:   return "Friends"
            }
        }
    }

    var canPost: Bool { !text.isEmpty || !attachments.isEmpty }

    func addAttachments(_ items: [PhotosPickerItem]) async {
        attachments += await AttachmentLoader.load(items)
    }

    /// Returns true when the post went through, so the view knows whether to
    /// dismiss.
    func submit() async -> Bool {
        guard canPost, !isPosting else { return false }
        isPosting = true
        errorMessage = nil
        defer { isPosting = false }
        do {
            try await PostsService.create(body: text, audience: audience, attachments: attachments)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
