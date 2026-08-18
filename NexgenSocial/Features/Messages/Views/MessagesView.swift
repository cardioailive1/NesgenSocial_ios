import SwiftUI

/// Conversation list, with a search field covering both existing chats and
/// friends the user hasn't messaged yet.
struct MessagesView: View {
    @StateObject private var model = MessagesViewModel()
    @EnvironmentObject private var session: AuthSession
    @EnvironmentObject private var callService: CallService

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.navy950.ignoresSafeArea()
                VStack(spacing: 0) {
                    Picker("", selection: $model.tab) {
                        ForEach(MessagesTab.allCases) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 8)

                    ErrorBanner(message: model.errorMessage)

                    switch model.tab {
                    case .chats: content
                    case .calls: callsList
                    }
                }
            }
            .navigationTitle("Messages")
            .searchable(text: $model.searchText,
                        placement: .navigationBarDrawer(displayMode: .always),
                        prompt: model.tab == .chats ? "Search chats and friends" : "Search calls")
            .navigationDestination(item: $model.openedConversation) { conversation in
                ConversationView(conversation: conversation)
            }
            .task {
                await model.load()
                await model.loadFriends()
                await model.loadCalls()
            }
            // A message notification names its conversation; `RootView` only
            // gets as far as this tab, so opening the thread happens here.
            .onReceive(NotificationCenter.default.publisher(for: .openDeepLink)) { note in
                guard let link = note.object as? String,
                      case .messages(let id?) = DeepLink.parse(link) else { return }
                Task { await model.open(conversationId: id) }
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

    /// Call history. Tapping a row calls that person back the same way they
    /// were reached before -- video rows redial video.
    @ViewBuilder
    private var callsList: some View {
        let calls = model.filteredCalls(forUserId: session.currentUser?.id)

        if calls.isEmpty {
            VStack(spacing: 8) {
                Text(model.isSearching ? "No matching calls" : "No calls yet")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                Text("Open a chat and tap the phone or video button to start one.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.slate400)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .frame(maxHeight: .infinity)
        } else {
            List(calls) { call in
                Button {
                    Task { await redial(call) }
                } label: {
                    CallHistoryRow(call: call, viewerId: session.currentUser?.id)
                }
                .listRowBackground(Theme.navy900)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .refreshable { await model.loadCalls() }
        }
    }

    private func redial(_ call: Call) async {
        guard let user = call.otherParty(forUserId: session.currentUser?.id) else { return }
        do {
            _ = try await callService.startOutgoingCall(to: user, video: call.isVideo)
        } catch {
            model.errorMessage = error.localizedDescription
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

private struct CallHistoryRow: View {
    let call: Call
    let viewerId: String?

    private var missed: Bool { call.wasMissed(forUserId: viewerId) }

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(url: call.otherParty(forUserId: viewerId)?.avatarUrl,
                       seed: call.otherParty(forUserId: viewerId)?.username ?? "?", size: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(call.otherParty(forUserId: viewerId)?.displayName ?? "Unknown")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(missed ? Theme.danger : .white)
                HStack(spacing: 5) {
                    Image(systemName: call.isOutgoing(forUserId: viewerId)
                          ? "arrow.up.right" : "arrow.down.left")
                        .font(.system(size: 10, weight: .bold))
                    Text(call.summary(forUserId: viewerId))
                        .font(.system(size: 12))
                }
                .foregroundStyle(missed ? Theme.danger : Theme.slate400)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Text(ServerDate.listTime(call.startedAt) ?? "")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.slate400)
                Image(systemName: call.isVideo ? "video.fill" : "phone.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.cyan400)
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
