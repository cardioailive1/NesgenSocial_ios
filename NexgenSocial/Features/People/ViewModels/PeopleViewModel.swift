import Foundation

@MainActor
final class PeopleViewModel: ObservableObject, LoadingViewModel {
    @Published private(set) var people: [User] = []
    @Published private(set) var suggestions: [FriendSuggestion] = []
    @Published private(set) var busyId: String?
    @Published var searchText = ""
    @Published var errorMessage: String?

    /// People the viewer has already acted on from the suggestions strip.
    /// The server only drops them on its next recomputation, and a row that
    /// stays put after a tap reads as the tap not registering.
    @Published private(set) var actedOnSuggestions: Set<String> = []

    var visibleSuggestions: [FriendSuggestion] {
        suggestions.filter { !actedOnSuggestions.contains($0.id) }.prefix(5).map { $0 }
    }

    func load() async {
        await attempt {
            people = try await DiscoveryService.people(matching: searchText.trimmingCharacters(in: .whitespaces))
        }
        // Suggestions are a nice-to-have: losing them shouldn't replace a more
        // useful error or produce one of their own.
        suggestions = (try? await FriendsService.suggestions()) ?? []
    }

    func toggleFollow(_ user: User) async {
        await act(user.id) {
            try await DiscoveryService.setFollowing(!(user.isFollowing ?? false), username: user.username)
        }
    }

    func addFriend(_ user: User) async {
        await act(user.id) { try await FriendsService.sendRequest(to: user.username) }
    }

    func acceptRequest(from user: User) async {
        guard let requestId = user.friendRequestId else { return }
        await act(user.id) { try await FriendsService.respond(to: requestId, accept: true) }
    }

    func cancelRequest(to user: User) async {
        guard let requestId = user.friendRequestId else { return }
        await act(user.id) { try await FriendsService.cancelRequest(requestId) }
    }

    func followSuggestion(_ suggestion: FriendSuggestion) async {
        actedOnSuggestions.insert(suggestion.id)
        await act(suggestion.id) {
            try await DiscoveryService.setFollowing(true, username: suggestion.username)
        }
    }

    func addSuggestion(_ suggestion: FriendSuggestion) async {
        actedOnSuggestions.insert(suggestion.id)
        await act(suggestion.id) { try await FriendsService.sendRequest(to: suggestion.username) }
    }

    private func act(_ id: String, _ work: () async throws -> Void) async {
        busyId = id
        defer { busyId = nil }
        do {
            try await work()
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
