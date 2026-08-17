import Foundation

@MainActor
final class SportsViewModel: ObservableObject {
    @Published private(set) var leagues: [SportsLeague] = []
    @Published private(set) var live: [SportsEvent] = []
    @Published private(set) var scores: SportsScoresResponse?
    /// Empty until the league list arrives: the server only accepts keys it
    /// publishes from /api/sports/leagues, so any hardcoded default is one
    /// backend league rename away from an "Unknown league" error on first load.
    @Published var selectedLeague = ""
    @Published var errorMessage: String?

    func loadAll() async {
        async let loadedLeagues = SportsService.leagues()
        async let loadedLive = SportsService.live()
        do {
            leagues = try await loadedLeagues
            live = try await loadedLive
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        if !leagues.contains(where: { $0.key == selectedLeague }) {
            selectedLeague = leagues.first?.key ?? ""
        }
        // No loadScores() here: assigning selectedLeague fires the view's
        // onChange, which loads them. Calling it too would double the request.
    }

    func loadScores() async {
        guard !selectedLeague.isEmpty else { return }
        do {
            scores = try await SportsService.scores(league: selectedLeague)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
