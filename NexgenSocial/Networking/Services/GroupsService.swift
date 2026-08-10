import Foundation

enum GroupsService {

    static func all() async throws -> [SocialGroup] {
        try await APIClient.shared.get(APIEndpoints.Groups.root, as: GroupsResponse.self).groups
    }

    static func mine() async throws -> [SocialGroup] {
        try await APIClient.shared.get(APIEndpoints.Groups.mine, as: GroupsResponse.self).groups
    }

    static func posts(in groupId: String) async throws -> [Post] {
        try await APIClient.shared.get(APIEndpoints.Groups.posts(groupId), as: FeedResponse.self).posts
    }

    static func members(of groupId: String) async throws -> [GroupMember] {
        try await APIClient.shared
            .get(APIEndpoints.Groups.members(groupId), as: GroupMembersResponse.self).members
    }

    static func setMembership(_ joined: Bool, groupId: String) async throws {
        let path = joined ? APIEndpoints.Groups.join(groupId) : APIEndpoints.Groups.leave(groupId)
        _ = try await APIClient.shared.post(path, as: EmptyResponse.self)
    }

    static func create(name: String, description: String, isPrivate: Bool) async throws -> SocialGroup {
        try await APIClient.shared.post(APIEndpoints.Groups.root,
                                        body: ["name": name,
                                               "description": description,
                                               "isPrivate": isPrivate],
                                        as: GroupResponse.self).group
    }
}
