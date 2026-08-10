import Foundation

enum SportsService {

    static func leagues() async throws -> [SportsLeague] {
        try await APIClient.shared
            .get(APIEndpoints.Sports.leagues, as: SportsLeaguesResponse.self).leagues
    }

    static func live() async throws -> [SportsEvent] {
        try await APIClient.shared.get(APIEndpoints.Sports.live, as: SportsLiveResponse.self).live
    }

    static func scores(league: String) async throws -> SportsScoresResponse {
        try await APIClient.shared
            .get(APIEndpoints.Sports.scores(league: league), as: SportsScoresResponse.self)
    }
}
