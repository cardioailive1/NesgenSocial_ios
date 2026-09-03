import SwiftUI

/// A single post with its comments and crowd-sourced context notes.
struct PostDetailView: View {
    @EnvironmentObject private var session: AuthSession
    @StateObject private var model: PostDetailViewModel
    @State private var showingNoteComposer = false
    @State private var showingEditor = false
    @State private var showingHistory = false

    /// Only the author can edit, which is also what the server enforces.
    private var isMine: Bool {
        model.post.author?.id != nil && model.post.author?.id == session.currentUser?.id
    }

    init(post: Post) {
        _model = StateObject(wrappedValue: PostDetailViewModel(post: post))
    }

    var body: some View {
        ZStack {
            Theme.navy950.ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        PostCard(post: model.post, onLike: {})
                            .padding(.horizontal, 14)

                        if !model.notes.isEmpty {
                            SectionHeader("Context")
                            ForEach(model.notes) { note in
                                ContextNoteCard(note: note) { value in
                                    await model.vote(note, value: value)
                                }
                                .padding(.horizontal, 14)
                            }
                        }

                        SectionHeader("Comments")

                        if model.comments.isEmpty {
                            Text("No comments yet.")
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.slate400)
                                .padding(.horizontal, 14)
                        }

                        ForEach(model.comments) { comment in
                            CommentRow(comment: comment)
                                .padding(.horizontal, 14)
                        }

                        ErrorBanner(message: model.errorMessage)
                    }
                    .padding(.vertical, 12)
                }

                HStack(spacing: 8) {
                    TextField("Add a comment…", text: $model.draft, axis: .vertical)
                        .lineLimit(1...4)
                        .fieldStyle()
                    Button {
                        Task { await model.sendComment() }
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 30))
                            .foregroundStyle(model.draft.isEmpty ? Theme.slate400 : Theme.cyan400)
                    }
                    .disabled(model.draft.isEmpty || model.isSending)
                }
                .padding(12)
                .background(Theme.navy900)
            }
        }
        .navigationTitle("Post")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Add context") { showingNoteComposer = true }
                    if isMine {
                        Button("Edit post") {
                            model.editDraft = model.post.body ?? ""
                            showingEditor = true
                        }
                    }
                    if model.post.editedAt != nil {
                        Button("Edit history") { showingHistory = true }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .tint(Theme.cyan400)
        .sheet(isPresented: $showingNoteComposer) {
            ContextNoteComposer(text: $model.noteDraft) {
                await model.addContextNote()
            }
        }
        .sheet(isPresented: $showingEditor) {
            PostEditor(text: $model.editDraft, original: model.post.body ?? "") {
                await model.saveEdit()
            }
        }
        .sheet(isPresented: $showingHistory) {
            PostHistoryView(revisions: model.revisions, current: model.post.body ?? "") {
                await model.loadHistory()
            }
        }
        .task { await model.load() }
    }
}


struct CommentRow: View {
    let comment: Comment

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            AvatarView(url: comment.author?.avatarUrl,
                       seed: comment.author?.username ?? "?", size: 32)
            VStack(alignment: .leading, spacing: 3) {
                Text(comment.author?.displayName ?? "Someone")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                Text(comment.body)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.slate300)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .card()
    }
}

struct ContextNoteCard: View {
    let note: ContextNote
    let onVote: (Int) async -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(note.body)
                .font(.system(size: 14))
                .foregroundStyle(Theme.slate300)
            HStack(spacing: 14) {
                Button {
                    Task { await onVote(1) }
                } label: {
                    Label("\(note.helpfulCount ?? 0)", systemImage: "hand.thumbsup")
                        .font(.system(size: 12))
                        .foregroundStyle(note.viewerVote == 1 ? Theme.cyan400 : Theme.slate400)
                }
                Button {
                    Task { await onVote(-1) }
                } label: {
                    Label("\(note.notHelpfulCount ?? 0)", systemImage: "hand.thumbsdown")
                        .font(.system(size: 12))
                        .foregroundStyle(note.viewerVote == -1 ? Theme.danger : Theme.slate400)
                }
                Spacer()
                Text("by @\(note.author?.username ?? "someone")")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.slate400)
            }
        }
        .padding(12)
        .card()
    }
}

struct ContextNoteComposer: View {
    @Binding var text: String
    @Environment(\.dismiss) private var dismiss
    let onSubmit: () async -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.navy950.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 12) {
                    Text("Add context readers can weigh for themselves. Notes are public with their vote tally.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.slate400)
                    TextEditor(text: $text)
                        .frame(minHeight: 140)
                        .scrollContentBackground(.hidden)
                        .padding(10)
                        .background(Theme.navy900)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .foregroundStyle(.white)
                    Spacer()
                }
                .padding(16)
            }
            .navigationTitle("Add context")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.tint(Theme.slate400)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") {
                        Task { await onSubmit(); dismiss() }
                    }
                    .tint(Theme.cyan400)
                    .disabled(text.isEmpty)
                }
            }
        }
    }
}


/// Editing is body-only: the server's PATCH takes nothing else, and media on
/// an existing post can't be changed.
struct PostEditor: View {
    @Binding var text: String
    let original: String
    let onSave: () async -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var busy = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.navy950.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 12) {
                    TextField("What's on your mind?", text: $text, axis: .vertical)
                        .lineLimit(4...12)
                        .fieldStyle()
                    Text("The earlier version is kept, and the post is marked as edited.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.slate400)
                    Spacer()
                }
                .padding(18)
            }
            .navigationTitle("Edit post")
            .navigationBarTitleDisplayMode(.inline)
            .tint(Theme.cyan400)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { text = original; dismiss() }.tint(Theme.slate400)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(busy ? "Saving…" : "Save") {
                        busy = true
                        Task {
                            if await onSave() { dismiss() }
                            busy = false
                        }
                    }
                    .disabled(busy
                              || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                              || text == original)
                }
            }
        }
    }
}

/// Oldest first, matching the server's order, with the live body last so the
/// list reads as a sequence rather than needing the post behind it.
struct PostHistoryView: View {
    let revisions: [PostRevision]?
    let current: String
    let onLoad: () async -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.navy950.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if let revisions {
                            ForEach(Array(revisions.enumerated()), id: \.element.id) { index, revision in
                                RevisionCard(label: "Version \(index + 1)",
                                             timestamp: revision.editedAt,
                                             text: revision.body)
                            }
                            RevisionCard(label: "Now", timestamp: nil, text: current)
                            if revisions.isEmpty {
                                Text("No earlier versions were recorded.")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Theme.slate400)
                            }
                        } else {
                            ProgressView().tint(Theme.cyan400)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                }
            }
            .navigationTitle("Edit history")
            .navigationBarTitleDisplayMode(.inline)
            .tint(Theme.cyan400)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }.tint(Theme.slate400)
                }
            }
            .task { if revisions == nil { await onLoad() } }
        }
    }
}

private struct RevisionCard: View {
    let label: String
    let timestamp: String?
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(label)
                if let stamp = ServerDate.listTime(timestamp) { Text("· \(stamp)") }
            }
            .font(.system(size: 11))
            .foregroundStyle(Theme.slate400)
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(Theme.slate300)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .card()
    }
}
