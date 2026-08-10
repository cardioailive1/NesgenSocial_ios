import Foundation

// Named `SocialGroup`, not `Group`: SwiftUI ships its own `Group` view, and
// the collision breaks every view builder in a file that imports both.

struct SocialGroup: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    var description: String?
    var isPrivate: Bool?
    var createdAt: String?
    var owner: User?
    var myRole: String?

    private enum CodingKeys: String, CodingKey {
        case id, name, description, isPrivate, createdAt, owner, myRole, _count
    }

    /// Prisma returns the member tally as `_count: { members: n }`.
    var memberCount: Int?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        isPrivate = try container.decodeIfPresent(Bool.self, forKey: .isPrivate)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        owner = try container.decodeIfPresent(User.self, forKey: .owner)
        myRole = try container.decodeIfPresent(String.self, forKey: .myRole)
        memberCount = try container.decodeIfPresent(GroupCount.self, forKey: ._count)?.members
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(isPrivate, forKey: .isPrivate)
    }
}

struct GroupCount: Codable, Hashable { let members: Int? }

struct GroupMember: Codable, Identifiable {
    let id: String
    let username: String
    let displayName: String
    var avatarUrl: String?
    var role: String?
    var isOwner: Bool?
}

struct GroupsResponse: Codable { let groups: [SocialGroup] }
struct GroupResponse: Codable { let group: SocialGroup }
struct GroupMembersResponse: Codable { let members: [GroupMember] }
