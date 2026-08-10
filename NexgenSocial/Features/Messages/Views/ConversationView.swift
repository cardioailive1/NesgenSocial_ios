import SwiftUI
import PhotosUI

struct ConversationView: View {
    @StateObject private var model: ConversationViewModel
    @EnvironmentObject private var callService: CallService
    @State private var selectedItems: [PhotosPickerItem] = []

    init(conversation: Conversation) {
        _model = StateObject(wrappedValue: ConversationViewModel(conversation: conversation))
    }

    var body: some View {
        ZStack {
            Theme.navy950.ignoresSafeArea()

            VStack(spacing: 0) {
                messageList
                composer
            }
        }
        .navigationTitle(model.title)
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
        }
        .tint(Theme.cyan400)
        .task { await model.load() }
        .task { await model.pollForNewMessages() }
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(model.messages) { message in
                        MessageBubble(message: message, isMine: model.isMine(message))
                            .id(message.id)
                    }
                }
                .padding(14)
            }
            .onChange(of: model.messages.count) { _, _ in
                withAnimation { proxy.scrollTo(model.messages.last?.id, anchor: .bottom) }
            }
        }
    }

    private var composer: some View {
        VStack(spacing: 8) {
            if !model.attachments.isEmpty {
                AttachmentStrip(attachments: $model.attachments, thumbnailSize: 56)
            }
            HStack(spacing: 8) {
                PhotosPicker(selection: $selectedItems, maxSelectionCount: 10,
                             matching: .any(of: [.images, .videos])) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 22))
                        .foregroundStyle(Theme.cyan300)
                }
                TextField("Message…", text: $model.draft, axis: .vertical)
                    .lineLimit(1...4)
                    .fieldStyle()
                Button {
                    Task { await model.send() }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(model.canSend ? Theme.cyan400 : Theme.slate400)
                }
                .disabled(!model.canSend || model.isSending)
            }
        }
        .padding(12)
        .background(Theme.navy900)
        .onChange(of: selectedItems) { _, newItems in
            Task {
                model.attachments += await AttachmentLoader.load(newItems)
                selectedItems = []
            }
        }
    }

    private func startCall(video: Bool) async {
        guard let user = model.otherUser else { return }
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
