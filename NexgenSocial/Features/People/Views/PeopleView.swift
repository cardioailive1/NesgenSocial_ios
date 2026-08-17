import SwiftUI

/// Everyone on the platform, mirroring the web People page: a "people you
/// might know" strip on top, then the full list with the follow and friend
/// actions that match the viewer's current relationship to each person.
struct PeopleView: View {
    @StateObject private var model = PeopleViewModel()

    var body: some View {
        ZStack {
            Theme.navy950.ignoresSafeArea()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    Text("Everyone on NexgenSocial. Follow to see their posts, or send a friend request to connect both ways. Sent requests wait for the other person to accept — you can track them on your Friends page.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.slate400)
                        .padding(.horizontal, 14)

                    ErrorBanner(message: model.errorMessage)

                    if !model.visibleSuggestions.isEmpty {
                        suggestionsCard
                            .padding(.horizontal, 14)
                    }

                    if model.people.isEmpty {
                        Text(model.searchText.isEmpty ? "No other accounts yet."
                                                      : "No one matches that search.")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.slate400)
                            .padding(.horizontal, 14)
                    }

                    ForEach(model.people) { person in
                        PersonRow(person: person, model: model)
                            .padding(.horizontal, 14)
                    }
                }
                .padding(.vertical, 12)
            }
            .refreshable { await model.load() }
        }
        .navigationTitle("People")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $model.searchText, prompt: "Search by name or username…")
        .onChange(of: model.searchText) { _, _ in Task { await model.load() } }
        .task { await model.load() }
    }

    private var suggestionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("People you might know")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.slate400)
                .textCase(.uppercase)

            ForEach(model.visibleSuggestions) { suggestion in
                HStack(spacing: 10) {
                    AvatarView(url: suggestion.avatarUrl, seed: suggestion.username, size: 38)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(suggestion.displayName ?? suggestion.username)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                        // Every suggestion carries its reason; an unexplained
                        // one is reasonably distrusted.
                        Text(suggestion.reason ?? "@\(suggestion.username)")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.cyan300)
                        if let occupation = suggestion.occupation, !occupation.isEmpty {
                            Text(occupation)
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.slate400)
                        }
                    }
                    Spacer(minLength: 0)
                    Button("Follow") { Task { await model.followSuggestion(suggestion) } }
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.cyan400)
                    Button("Add") { Task { await model.addSuggestion(suggestion) } }
                        .tint(Theme.slate300)
                }
                .font(.system(size: 12))
                .disabled(model.busyId == suggestion.id)
            }
        }
        .padding(12)
        .card()
    }
}

/// One row in the full list. The right-hand buttons are driven entirely by
/// the relationship fields the list endpoint returns.
struct PersonRow: View {
    let person: User
    @ObservedObject var model: PeopleViewModel

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(url: person.avatarUrl, seed: person.username, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(person.displayName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                Text("@\(person.username)")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.slate400)
                if let bio = person.bio, !bio.isEmpty {
                    Text(bio)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.slate300)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 6) {
                Button((person.isFollowing ?? false) ? "Unfollow" : "Follow") {
                    Task { await model.toggleFollow(person) }
                }
                .buttonStyle(.borderedProminent)
                .tint((person.isFollowing ?? false) ? Theme.navy800 : Theme.cyan400)

                friendAction
            }
            .font(.system(size: 11))
            .disabled(model.busyId == person.id)
        }
        .padding(12)
        .card()
    }

    @ViewBuilder
    private var friendAction: some View {
        switch (person.friendStatus ?? "NONE", person.friendRequestIncoming ?? false) {
        case ("ACCEPTED", _):
            Text("FRIENDS")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.cyan300)
        case ("PENDING", true):
            Button("Accept request") { Task { await model.acceptRequest(from: person) } }
                .buttonStyle(.borderedProminent)
                .tint(Theme.cyan400)
        case ("PENDING", false):
            HStack(spacing: 6) {
                Text("REQUEST SENT")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Theme.slate400)
                Button("Cancel") { Task { await model.cancelRequest(to: person) } }
                    .tint(Theme.danger)
            }
        default:
            Button("Add friend") { Task { await model.addFriend(person) } }
                .tint(Theme.slate300)
        }
    }
}
