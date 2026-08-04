import SwiftUI

@MainActor
final class MessagesViewModel: ObservableObject {
    @Published var conversations: [Conversation] = []
    @Published var isLoading = false

    func load() async {
        isLoading = true
        defer { isLoading = false }
        conversations = (try? await APIClient.shared
            .get("/api/messages", as: ConversationsResponse.self).conversations) ?? []
    }
}

struct MessagesView: View {
    @StateObject private var model = MessagesViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.navy950.ignoresSafeArea()

                if model.conversations.isEmpty && !model.isLoading {
                    VStack(spacing: 8) {
                        Text("No conversations yet")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                        Text("Open someone's profile and tap Message.")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.slate400)
                    }
                } else {
                    List(model.conversations) { convo in
                        NavigationLink {
                            ConversationView(conversation: convo)
                        } label: {
                            HStack(spacing: 12) {
                                AvatarView(url: convo.otherUser?.avatarUrl,
                                           seed: convo.otherUser?.username ?? "?", size: 44)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(convo.otherUser?.displayName ?? "Conversation")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(.white)
                                    Text(convo.lastMessage?.body ?? "No messages yet")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Theme.slate400)
                                        .lineLimit(1)
                                }
                                Spacer()
                                if let unread = convo.unreadCount, unread > 0 {
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
                        .listRowBackground(Theme.navy900)
                    }
                    .scrollContentBackground(.hidden)
                    .refreshable { await model.load() }
                }
            }
            .navigationTitle("Messages")
            .task { await model.load() }
        }
    }
}

struct ConversationView: View {
    let conversation: Conversation
    @EnvironmentObject var callService: CallService

    @State private var messages: [Message] = []
    @State private var draft = ""
    @State private var isSending = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Theme.navy950.ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(messages) { message in
                                MessageBubble(message: message,
                                              isMine: message.sender?.id != conversation.otherUser?.id)
                                    .id(message.id)
                            }
                        }
                        .padding(14)
                    }
                    .onChange(of: messages.count) { _, _ in
                        withAnimation { proxy.scrollTo(messages.last?.id, anchor: .bottom) }
                    }
                }

                HStack(spacing: 8) {
                    TextField("Message…", text: $draft, axis: .vertical)
                        .lineLimit(1...4)
                        .fieldStyle()
                    Button {
                        Task { await send() }
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 30))
                            .foregroundStyle(draft.isEmpty ? Theme.slate400 : Theme.cyan400)
                    }
                    .disabled(draft.isEmpty || isSending)
                }
                .padding(12)
                .background(Theme.navy900)
            }
        }
        .navigationTitle(conversation.otherUser?.displayName ?? "Chat")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    Task { await startCall(video: false) }
                } label: { Image(systemName: "phone.fill") }
                Button {
                    Task { await startCall(video: true) }
                } label: { Image(systemName: "video.fill") }
            }
            .tint(Theme.cyan400)
        }
        .task { await load() }
        // Polling keeps this simple and predictable. A socket would be
        // lower-latency but adds reconnection handling for little gain at
        // current scale.
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                await load()
            }
        }
    }

    private func load() async {
        messages = (try? await APIClient.shared
            .get("/api/messages/\(conversation.id)/messages", as: MessagesResponse.self).messages) ?? []
    }

    private func send() async {
        isSending = true
        defer { isSending = false }
        let text = draft
        draft = ""
        do {
            _ = try await APIClient.shared.upload(
                "/api/messages/\(conversation.id)/messages",
                fields: ["body": text], files: [], as: EmptyResponse.self
            )
            await load()
        } catch {
            draft = text  // restore so the message isn't lost
            errorMessage = error.localizedDescription
        }
    }

    private func startCall(video: Bool) async {
        guard let user = conversation.otherUser else { return }
        _ = try? await callService.startOutgoingCall(to: user, video: video)
    }
}

struct MessageBubble: View {
    let message: Message
    let isMine: Bool

    var body: some View {
        HStack {
            if isMine { Spacer(minLength: 50) }
            VStack(alignment: .leading, spacing: 6) {
                if let body = message.body, !body.isEmpty {
                    Text(body)
                        .font(.system(size: 14.5))
                        .foregroundStyle(isMine ? Theme.navy950 : .white)
                }
                if let attachments = message.attachments, !attachments.isEmpty {
                    MediaCarousel(items: attachments)
                        .frame(maxWidth: 240)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 9)
            .background(isMine ? Theme.cyan400 : Theme.navy800)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            if !isMine { Spacer(minLength: 50) }
        }
    }
}
