import SwiftUI
import PhotosUI

struct ConversationView: View {
    @StateObject private var model: ConversationViewModel
    @EnvironmentObject private var callService: CallService
    @State private var selectedItems: [PhotosPickerItem] = []
    @Environment(\.scenePhase) private var scenePhase

    init(conversation: Conversation) {
        _model = StateObject(wrappedValue: ConversationViewModel(conversation: conversation))
    }

    var body: some View {
        ZStack {
            Theme.navy950.ignoresSafeArea()

            VStack(spacing: 0) {
                messageList
                ErrorBanner(message: model.errorMessage)
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
        // Keyed on the scene phase so the poll is cancelled when the app
        // leaves the foreground: a backgrounded chat used to keep hitting the
        // API every 5 seconds for as long as the process lived.
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            await model.pollForNewMessages()
        }
        // Reading the thread is what clears its unread count on the server,
        // so the tab badge is only right once the reader has left.
        .onDisappear { Task { await UnreadBadge.shared.refresh() } }
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(Array(model.messages.enumerated()), id: \.element.id) { index, message in
                        if let day = dayLabel(at: index) {
                            Text(day)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Theme.slate400)
                                .padding(.horizontal, 10).padding(.vertical, 4)
                                .background(Theme.navy900)
                                .clipShape(Capsule())
                                .padding(.vertical, 6)
                        }
                        MessageBubble(message: message, isMine: model.isMine(message))
                            .id(message.id)
                            // Only the viewer's own messages: the route
                            // rejects anyone else's, and offering an action
                            // that always fails is worse than not offering it.
                            .contextMenu {
                                if model.isMine(message) {
                                    Button("Delete", systemImage: "trash", role: .destructive) {
                                        Task { await model.delete(message) }
                                    }
                                }
                            }
                    }
                }
                .padding(14)
            }
            .onChange(of: model.messages.count) { _, _ in
                withAnimation { proxy.scrollTo(model.messages.last?.id, anchor: .bottom) }
            }
        }
    }

    /// A day heading, shown only on the first message of each day.
    private func dayLabel(at index: Int) -> String? {
        guard let label = ServerDate.dayLabel(model.messages[index].createdAt) else { return nil }
        guard index > 0 else { return label }
        return ServerDate.dayLabel(model.messages[index - 1].createdAt) == label ? nil : label
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
        do {
            _ = try await callService.startOutgoingCall(to: user, video: video)
        } catch {
            model.errorMessage = error.localizedDescription
        }
    }
}

struct MessageBubble: View {
    let message: Message
    let isMine: Bool

    /// Keeps a long message off both edges of the screen instead of letting
    /// one paragraph stretch the full width, which is what makes a wall of
    /// text unreadable.
    private let maxBubbleWidth: CGFloat = 290

    private var textColor: Color { isMine ? Theme.navy950 : .white }

    private var photosAndVideos: [MediaItem] {
        (message.attachments ?? []).filter { $0.kind != .file }
    }

    private var files: [MediaItem] {
        (message.attachments ?? []).filter { $0.kind == .file }
    }

    var body: some View {
        HStack {
            if isMine { Spacer(minLength: 44) }

            VStack(alignment: .leading, spacing: 8) {
                if !photosAndVideos.isEmpty {
                    MediaCarousel(items: photosAndVideos)
                        .frame(maxWidth: maxBubbleWidth)
                }

                ForEach(files) { file in
                    FileAttachmentCard(item: file, onDark: !isMine)
                        .frame(maxWidth: maxBubbleWidth)
                }

                if let body = message.body, !body.isEmpty {
                    Text(body)
                        .font(.system(size: 15))
                        // Long messages wrap and keep their line breaks
                        // rather than being clipped to one line.
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                        .foregroundStyle(textColor)
                }

                if let time = ServerDate.clockTime(message.createdAt) {
                    Text(time)
                        .font(.system(size: 10.5))
                        .foregroundStyle(isMine ? Theme.navy950.opacity(0.65) : Theme.slate400)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 9)
            .frame(maxWidth: maxBubbleWidth, alignment: .leading)
            .background(isMine ? Theme.cyan400 : Theme.navy800)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isMine ? Color.clear : Theme.line, lineWidth: 1)
            )

            if !isMine { Spacer(minLength: 44) }
        }
    }
}

/// A non-media attachment: a PDF, a document, an archive.
///
/// ponytail: the server only stores PHOTO and VIDEO today, so nothing decodes
/// to `.file` yet -- this is what renders the moment it does, rather than an
/// empty bubble. Tapping opens the file in the system browser, which handles
/// preview and "save to Files" without a QuickLook stack here.
struct FileAttachmentCard: View {
    let item: MediaItem
    let onDark: Bool

    @Environment(\.openURL) private var openURL

    private var filename: String {
        let name = (item.url as NSString).lastPathComponent
        return name.isEmpty ? "Attachment" : name
    }

    /// Icon per file type -- a spreadsheet and a zip shouldn't look alike.
    private var icon: String {
        switch (item.url as NSString).pathExtension.lowercased() {
        case "pdf":                          return "doc.richtext"
        case "doc", "docx", "rtf", "txt":    return "doc.text"
        case "xls", "xlsx", "csv", "numbers":return "tablecells"
        case "ppt", "pptx", "key":           return "rectangle.on.rectangle"
        case "zip", "rar", "7z", "tar", "gz":return "doc.zipper"
        case "mp3", "m4a", "wav", "aac":     return "waveform"
        default:                             return "doc"
        }
    }

    var body: some View {
        Button {
            if let url = APIClient.mediaURL(item.url) { openURL(url) }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .frame(width: 38, height: 38)
                    .background(onDark ? Theme.navy950 : Theme.navy950.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(filename)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(item.caption ?? "Tap to open")
                        .font(.system(size: 11))
                        .opacity(0.75)
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(onDark ? Color.white : Theme.navy950)
            .padding(8)
            .background(onDark ? Theme.navy900 : Color.white.opacity(0.25))
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
