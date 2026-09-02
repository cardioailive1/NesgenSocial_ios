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
                    Text("Friend requests need both people to agree. Once you send one it sits here until the other person accepts it.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.slate400)
                        .padding(.horizontal, 14)

                    HStack(spacing: 10) {
                        TextField("Add a friend by username", text: $model.usernameToAdd)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .fieldStyle()
                        Button("Send request") { Task { await model.sendRequestByUsername() } }
                            .font(.system(size: 13, weight: .semibold))
                            .buttonStyle(.borderedProminent)
                            .tint(Theme.cyan400)
                            .disabled(model.usernameToAdd.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    .padding(12)
                    .card()
                    .padding(.horizontal, 14)

                    if let notice = model.notice {
                        Text(notice)
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.cyan300)
                            .padding(.horizontal, 14)
                    }

                    ErrorBanner(message: model.errorMessage)

                    SectionHeader("Requests waiting on you (\(model.incoming.count))")
                    if model.incoming.isEmpty {
                        Text("No one's asked to be your friend right now.")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.slate400)
                            .padding(.horizontal, 14)
                    } else {
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

                    SectionHeader("Requests you've sent (\(model.sent.count))")
                    if model.sent.isEmpty {
                        Text("You haven't sent any requests that are still pending.")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.slate400)
                            .padding(.horizontal, 14)
                    } else {
                        ForEach(model.sent) { request in
                            FriendRow(user: request.receiver, subtitle: "awaiting reply") {
                                Button("Cancel") { Task { await model.cancel(request) } }
                                    .font(.system(size: 12))
                                    .tint(Theme.danger)
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

                    SectionHeader("Friends (\(model.friends.count))")
                    if model.friends.isEmpty {
                        Text("No friends yet. Try the People page to find someone.")
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
            .pullToRefresh { await model.load() }
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
