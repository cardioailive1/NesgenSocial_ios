import Foundation

@MainActor
final class SportsViewModel: ObservableObject {
    @Published private(set) var leagues: [SportsLeague] = []
    @Published private(set) var live: [SportsEvent] = []
    @Published private(set) var scores: SportsScoresResponse?
    @Published var selectedLeague = "soccer"
    @Published var errorMessage: String?

    func loadAll() async {
        async let loadedLeagues = try? SportsService.leagues()
        async let loadedLive = try? SportsService.live()
        leagues = await loadedLeagues ?? []
        live = await loadedLive ?? []
        await loadScores()
    }

    func loadScores() async {
        do {
            scores = try await SportsService.scores(league: selectedLeague)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
