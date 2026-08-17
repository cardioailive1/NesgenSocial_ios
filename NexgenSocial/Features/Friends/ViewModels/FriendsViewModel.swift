import Foundation

@MainActor
final class FriendsViewModel: ObservableObject {
    @Published var incoming: [FriendRequest] = []
    @Published var sent: [FriendRequest] = []
    @Published var friends: [User] = []
    @Published var suggestions: [FriendSuggestion] = []
    @Published var errorMessage: String?

    func load() async {
        do {
            let response = try await FriendsService.overview()
            incoming = response.incomingRequests
            sent = response.sentRequests
            friends = response.friends
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        // Suggestions are a nice-to-have: losing them shouldn't overwrite a
        // more useful error, or produce one of their own.
        suggestions = (try? await FriendsService.suggestions()) ?? []
    }

    func sendRequest(to suggestion: FriendSuggestion) async {
        do {
            try await FriendsService.sendRequest(to: suggestion.username)
            // Drop it locally rather than waiting for the reload: the server
            // won't return it as a suggestion again, and the row disappearing
            // late reads as the tap not registering.
            suggestions.removeAll { $0.id == suggestion.id }
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func respond(to request: FriendRequest, accept: Bool) async {
        do {
            try await FriendsService.respond(to: request.id, accept: accept)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func cancel(_ request: FriendRequest) async {
        do {
            try await FriendsService.cancelRequest(request.id)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func remove(_ friend: User) async {
        do {
            try await FriendsService.remove(friend.id)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
