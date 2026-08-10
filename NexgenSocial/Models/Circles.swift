import Foundation

struct CircleMembership: Codable, Identifiable {
    let id: String
    var user: User?
}

// Named `AudienceCircle`, not `Circle`, for the same reason as
// `SocialGroup`: SwiftUI ships a `Circle` shape.
struct AudienceCircle: Codable, Identifiable {
    let id: String
    let name: String
    var members: [CircleMembership]?
}

struct CirclesResponse: Codable { let circles: [AudienceCircle] }
struct CircleResponse: Codable { let circle: AudienceCircle }
