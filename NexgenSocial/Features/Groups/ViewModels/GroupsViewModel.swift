import Foundation
import SwiftUI
import PhotosUI

@MainActor
final class GroupsViewModel: ObservableObject, LoadingViewModel {
    @Published private(set) var discover: [SocialGroup] = []
    @Published private(set) var mine: [SocialGroup] = []
    @Published var errorMessage: String?

    func load() async {
        // `async let` can't cross a closure boundary, so the pair is started
        // inside `attempt` rather than around it.
        await attempt {
            async let all = GroupsService.all()
            async let joined = GroupsService.mine()
            mine = try await joined
            let mineIds = Set(mine.map(\.id))
            discover = try await all.filter { !mineIds.contains($0.id) }
        }
    }
}

@MainActor
final class GroupDetailViewModel: ObservableObject, LoadingViewModel {
    @Published private(set) var posts: [Post] = []
    @Published private(set) var members: [GroupMember] = []
    @Published private(set) var isMember = false
    @Published var errorMessage: String?

    @Published var composerText = ""
    @Published var composerAttachments: [PickedAttachment] = []
    @Published private(set) var isPosting = false

    private let group: SocialGroup

    init(group: SocialGroup) {
        self.group = group
        isMember = group.myRole != nil
    }

    func load() async {
        await attempt { [group] in
            async let loadedPosts = GroupsService.posts(in: group.id)
            async let loadedMembers = GroupsService.members(of: group.id)
            posts = try await loadedPosts
            members = try await loadedMembers
        }
    }

    var canPost: Bool { !composerText.isEmpty || !composerAttachments.isEmpty }

    func addAttachments(_ items: [PhotosPickerItem]) async {
        composerAttachments += await AttachmentLoader.load(items)
    }

    func submitPost() async {
        guard canPost, !isPosting else { return }
        isPosting = true
        defer { isPosting = false }
        do {
            try await GroupsService.createPost(in: group.id,
                                               body: composerText,
                                               attachments: composerAttachments)
            composerText = ""
            composerAttachments = []
            errorMessage = nil
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleMembership() async {
        do {
            try await GroupsService.setMembership(!isMember, groupId: group.id)
            isMember.toggle()
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
