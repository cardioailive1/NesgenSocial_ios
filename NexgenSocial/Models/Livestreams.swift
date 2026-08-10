import Foundation

struct Livestream: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    var status: String?
    var startedAt: String?
    var host: User?
    var newsroom: NewsroomRef?
}

struct LivestreamsResponse: Codable { let streams: [Livestream] }
struct LivestreamResponse: Codable { let stream: Livestream }
