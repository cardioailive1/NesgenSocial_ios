import Foundation

@MainActor
final class GroupsViewModel: ObservableObject {
    @Published private(set) var discover: [SocialGroup] = []
    @Published private(set) var mine: [SocialGroup] = []

    func load() async {
        async let all = try? GroupsService.all()
        async let joined = try? GroupsService.mine()
        mine = await joined ?? []
        let mineIds = Set(mine.map(\.id))
        discover = (await all ?? []).filter { !mineIds.contains($0.id) }
    }
}

@MainActor
final class GroupDetailViewModel: ObservableObject {
    @Published private(set) var posts: [Post] = []
    @Published private(set) var members: [GroupMember] = []
    @Published private(set) var isMember = false
    @Published var errorMessage: String?

    private let group: SocialGroup

    init(group: SocialGroup) {
        self.group = group
        isMember = group.myRole != nil
    }

    func load() async {
        async let loadedPosts = try? GroupsService.posts(in: group.id)
        async let loadedMembers = try? GroupsService.members(of: group.id)
        posts = await loadedPosts ?? []
        members = await loadedMembers ?? []
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
