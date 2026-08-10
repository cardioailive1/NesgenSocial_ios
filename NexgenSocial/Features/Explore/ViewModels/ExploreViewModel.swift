import Foundation

@MainActor
final class ExploreViewModel: ObservableObject {

    enum Section: Int, CaseIterable {
        case people, jobs, market

        var title: String {
            switch self {
            case .people: return "People"
            case .jobs:   return "Jobs"
            case .market: return "Market"
            }
        }
    }

    @Published var users: [User] = []
    @Published var jobs: [JobPosting] = []
    @Published var listings: [MarketListing] = []
    @Published var searchText = ""
    @Published var section: Section = .people

    /// Only the visible section is fetched. Loading all three on every
    /// keystroke would triple the traffic for results nobody is looking at.
    func load() async {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        switch section {
        case .people: users = (try? await DiscoveryService.users(matching: query)) ?? []
        case .jobs:   jobs = (try? await DiscoveryService.jobs(matching: query)) ?? []
        case .market: listings = (try? await DiscoveryService.listings(matching: query)) ?? []
        }
    }
}
