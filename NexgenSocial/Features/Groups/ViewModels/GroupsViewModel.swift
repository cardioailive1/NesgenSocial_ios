import Foundation

@MainActor
final class GroupsViewModel: ObservableObject {
    @Published private(set) var discover: [SocialGroup] = []
    @Published private(set) var mine: [SocialGroup] = []
    @Published var errorMessage: String?

    func load() async {
        async let all = GroupsService.all()
        async let joined = GroupsService.mine()
        do {
            mine = try await joined
            let mineIds = Set(mine.map(\.id))
            discover = try await all.filter { !mineIds.contains($0.id) }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
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
        async let loadedPosts = GroupsService.posts(in: group.id)
        async let loadedMembers = GroupsService.members(of: group.id)
        do {
            posts = try await loadedPosts
            members = try await loadedMembers
            errorMessage = nil
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
