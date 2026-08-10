import SwiftUI

/// A single post with its comments and crowd-sourced context notes.
struct PostDetailView: View {
    @StateObject private var model: PostDetailViewModel
    @State private var showingNoteComposer = false

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

                        if let errorMessage = model.errorMessage {
                            Text(errorMessage)
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.danger)
                                .padding(.horizontal, 14)
                        }
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
                Button("Add context") { showingNoteComposer = true }
                    .font(.system(size: 13))
            }
        }
        .tint(Theme.cyan400)
        .sheet(isPresented: $showingNoteComposer) {
            ContextNoteComposer(text: $model.noteDraft) {
                await model.addContextNote()
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
