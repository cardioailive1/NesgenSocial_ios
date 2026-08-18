import Foundation

struct SportsLeague: Codable, Identifiable, Hashable {
    let key: String
    let label: String
    var sport: String?
    var verified: Bool?
    var broadcastUrl: String?

    var id: String { key }
}

/// TheSportsDB hands back scores as `"2"` on some endpoints and `2` on
/// others. Decoding either keeps one inconsistent field from blanking the
/// whole scores screen.
struct LooseString: Codable, Hashable {
    let text: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { text = nil }
        else if let string = try? container.decode(String.self) { text = string }
        else if let int = try? container.decode(Int.self) { text = String(int) }
        else { text = nil }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(text)
    }
}

struct SportsEvent: Codable, Identifiable, Hashable {
    let id: String
    var homeTeam: String?
    var awayTeam: String?
    var homeScore: LooseString?
    var awayScore: LooseString?
    var date: String?
    var time: String?
    var venue: String?
    var status: String?
    var isLive: Bool?
    var league: String?
    var broadcastUrl: String?

    var scoreLine: String {
        guard let home = homeScore?.text, let away = awayScore?.text else { return "" }
        return "\(home) – \(away)"
    }
}

struct SportsLeaguesResponse: Codable { let leagues: [SportsLeague] }
struct SportsLiveResponse: Codable { let live: [SportsEvent] }

struct SportsScoresResponse: Codable {
    let league: String
    var broadcastUrl: String?
    let upcoming: [SportsEvent]
    let recent: [SportsEvent]
    var noData: Bool?
    var verified: Bool?
}
