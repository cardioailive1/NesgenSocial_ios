import SwiftUI

/// Friend requests in both directions, plus the accepted list. Outgoing
/// requests are shown so a sent request stays visible until it's answered.
struct FriendsView: View {
    @StateObject private var model = FriendsViewModel()

    var body: some View {
        ZStack {
            Theme.navy950.ignoresSafeArea()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    if let errorMessage = model.errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.danger)
                            .padding(.horizontal, 14)
                    }

                    if !model.incoming.isEmpty {
                        SectionHeader("Requests")
                        ForEach(model.incoming) { request in
                            FriendRow(user: request.sender,
                                      subtitle: "wants to be friends") {
                                HStack(spacing: 8) {
                                    Button("Accept") {
                                        Task { await model.respond(to: request, accept: true) }
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(Theme.cyan400)
                                    Button("Decline") {
                                        Task { await model.respond(to: request, accept: false) }
                                    }
                                    .tint(Theme.slate400)
                                }
                                .font(.system(size: 12))
                            }
                            .padding(.horizontal, 14)
                        }
                    }

                    if !model.sent.isEmpty {
                        SectionHeader("Sent")
                        ForEach(model.sent) { request in
                            FriendRow(user: request.receiver, subtitle: "request pending") {
                                Button("Cancel") { Task { await model.cancel(request) } }
                                    .font(.system(size: 12))
                                    .tint(Theme.slate400)
                            }
                            .padding(.horizontal, 14)
                        }
                    }

                    if !model.suggestions.isEmpty {
                        SectionHeader("People you may know")
                        ForEach(model.suggestions) { suggestion in
                            SuggestionRow(suggestion: suggestion) {
                                await model.sendRequest(to: suggestion)
                            }
                            .padding(.horizontal, 14)
                        }
                    }

                    SectionHeader("Friends")
                    if model.friends.isEmpty {
                        Text("No friends yet. Send a request from someone's profile.")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.slate400)
                            .padding(.horizontal, 14)
                    }
                    ForEach(model.friends) { friend in
                        FriendRow(user: friend, subtitle: "@\(friend.username)") {
                            Button("Remove") { Task { await model.remove(friend) } }
                                .font(.system(size: 12))
                                .tint(Theme.danger)
                        }
                        .padding(.horizontal, 14)
                    }
                }
                .padding(.vertical, 12)
            }
            .refreshable { await model.load() }
        }
        .navigationTitle("Friends")
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load() }
    }
}

/// A suggestion always shows why it was made. An unexplained "people you may
/// know" row is one people reasonably distrust, and the server sends the
/// reason for exactly that purpose.
struct SuggestionRow: View {
    let suggestion: FriendSuggestion
    let onAdd: () async -> Void

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(url: suggestion.avatarUrl, seed: suggestion.username, size: 42)
            VStack(alignment: .leading, spacing: 2) {
                Text(suggestion.displayName ?? suggestion.username)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                Text(suggestion.reason ?? "@\(suggestion.username)")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.slate400)
            }
            Spacer(minLength: 0)
            Button("Add") { Task { await onAdd() } }
                .font(.system(size: 12))
                .buttonStyle(.borderedProminent)
                .tint(Theme.cyan400)
        }
        .padding(12)
        .card()
    }
}

struct FriendRow<Actions: View>: View {
    let user: User?
    let subtitle: String
    @ViewBuilder let actions: () -> Actions

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(url: user?.avatarUrl, seed: user?.username ?? "?", size: 42)
            VStack(alignment: .leading, spacing: 2) {
                Text(user?.displayName ?? "Someone")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.slate400)
            }
            Spacer(minLength: 0)
            actions()
        }
        .padding(12)
        .card()
    }
}
