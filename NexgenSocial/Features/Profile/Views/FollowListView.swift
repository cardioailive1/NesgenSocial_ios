import SwiftUI

/// The people behind the follower and following counts on a profile.
///
/// One screen for both directions: the two routes return the same shape, and
/// the only differences are the title and which one is called.
struct FollowListView: View {

    enum Direction: String {
        case followers = "Followers"
        case following = "Following"
    }

    let username: String
    let direction: Direction

    @State private var people: [User] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Theme.navy950.ignoresSafeArea()

            if isLoading {
                ProgressView().tint(Theme.cyan400)
            } else if people.isEmpty {
                VStack(spacing: 6) {
                    Text(direction == .followers ? "No followers yet" : "Not following anyone yet")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.slate400)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 30)
            } else {
                // Rows don't navigate: the app has no screen for someone
                // else's profile yet. Add the link when one exists.
                List(people) { person in
                    FollowPersonRow(person: person)
                        .listRowBackground(Theme.navy900)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .pullToRefresh { await load() }
            }
        }
        .navigationTitle(direction.rawValue)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        defer { isLoading = false }
        do {
            people = direction == .followers
                ? try await DiscoveryService.followers(of: username)
                : try await DiscoveryService.following(of: username)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// Deliberately not `PersonRow`: that one is bound to `PeopleViewModel` for
/// its follow and friend buttons, and these rows carry no relationship
/// fields to drive them with.
private struct FollowPersonRow: View {
    let person: User

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
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }
}
