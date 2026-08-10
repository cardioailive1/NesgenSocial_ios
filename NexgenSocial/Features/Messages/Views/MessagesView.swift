import SwiftUI

/// Conversation list, with a search field covering both existing chats and
/// friends the user hasn't messaged yet.
struct MessagesView: View {
    @StateObject private var model = MessagesViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.navy950.ignoresSafeArea()
                content
            }
            .navigationTitle("Messages")
            .searchable(text: $model.searchText,
                        placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Search chats and friends")
            .navigationDestination(item: $model.openedConversation) { conversation in
                ConversationView(conversation: conversation)
            }
            .task {
                await model.load()
                await model.loadFriends()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if model.filteredConversations.isEmpty && model.matchingFriends.isEmpty && !model.isLoading {
            emptyState
        } else {
            List {
                if !model.filteredConversations.isEmpty {
                    Section {
                        ForEach(model.filteredConversations) { conversation in
                            NavigationLink {
                                ConversationView(conversation: conversation)
                            } label: {
                                ConversationRow(conversation: conversation)
                            }
                            .listRowBackground(Theme.navy900)
                        }
                    } header: {
                        if model.isSearching { listHeader("Chats") }
                    }
                }

                // Only shown while searching: "who else can I message?" is not
                // a question anyone is asking when they open this screen to
                // read an existing thread.
                if !model.matchingFriends.isEmpty {
                    Section {
                        ForEach(model.matchingFriends) { friend in
                            Button {
                                Task { await model.startChat(with: friend) }
                            } label: {
                                FriendSearchRow(user: friend)
                            }
                            .listRowBackground(Theme.navy900)
                        }
                    } header: {
                        listHeader("Start a new chat")
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .refreshable { await model.load() }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text(model.isSearching ? "No matches" : "No conversations yet")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
            Text(model.isSearching
                 ? "Search by name or @username."
                 : "Search for a friend above, or open someone's profile and tap Message.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.slate400)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    private func listHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Theme.slate400)
    }
}

private struct ConversationRow: View {
    let conversation: Conversation

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(url: conversation.otherUser?.avatarUrl,
                       seed: conversation.otherUser?.username ?? "?", size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(conversation.otherUser?.displayName ?? "Conversation")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                Text(conversation.lastMessage?.body ?? "No messages yet")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.slate400)
                    .lineLimit(1)
            }
            Spacer()
            if let unread = conversation.unreadCount, unread > 0 {
                Text("\(unread)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.navy950)
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(Theme.cyan400)
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 4)
    }
}

private struct FriendSearchRow: View {
    let user: User

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(url: user.avatarUrl, seed: user.username, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                Text("@\(user.username)")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.slate400)
            }
            Spacer()
            Image(systemName: "square.and.pencil")
                .font(.system(size: 15))
                .foregroundStyle(Theme.cyan400)
        }
        .padding(.vertical, 4)
    }
}
