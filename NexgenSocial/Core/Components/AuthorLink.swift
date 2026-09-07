import SwiftUI

/// Wraps an author's name and avatar in a link to their profile.
///
/// Tapping your own name does nothing: opening a second copy of your own
/// profile, without the settings and the avatar picker that belong to it,
/// reads as a bug rather than a feature. That check lives here so the seven
/// places showing an author don't each repeat it.
struct AuthorLink<Content: View>: View {
    let username: String?
    @ViewBuilder let content: () -> Content

    @EnvironmentObject private var session: AuthSession

    var body: some View {
        if let username, !username.isEmpty, username != session.currentUser?.username {
            NavigationLink { PersonProfileView(username: username) } label: { content() }
                .buttonStyle(.plain)
        } else {
            content()
        }
    }
}

/// A username to push a profile for. `navigationDestination(item:)` needs an
/// `Identifiable`, and conforming `String` itself would apply to every string
/// in the app.
struct ProfileRoute: Identifiable, Hashable {
    let username: String
    var id: String { username }
}
