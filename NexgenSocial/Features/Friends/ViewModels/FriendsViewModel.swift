import Foundation

@MainActor
final class FriendsViewModel: ObservableObject {
    @Published var incoming: [FriendRequest] = []
    @Published var sent: [FriendRequest] = []
    @Published var friends: [User] = []
    @Published var suggestions: [FriendSuggestion] = []
    @Published var usernameToAdd = ""
    @Published var notice: String?
    @Published var errorMessage: String?

    /// Sends to the username typed in the add field. The confirmation says
    /// where the request went — a transient "sent" state with no follow-up
    /// reads as if nothing happened.
    func sendRequestByUsername() async {
        let username = usernameToAdd.trimmingCharacters(in: .whitespaces)
        guard !username.isEmpty else { return }
        do {
            try await FriendsService.sendRequest(to: username)
            notice = "Request sent to @\(username). It's waiting for them to accept — you'll find it under \"Requests you've sent\"."
            usernameToAdd = ""
            errorMessage = nil
            await load()
        } catch {
            notice = nil
            errorMessage = error.localizedDescription
        }
    }

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
