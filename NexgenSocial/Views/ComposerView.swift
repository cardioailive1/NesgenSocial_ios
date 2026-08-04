import SwiftUI
import PhotosUI
import AVFoundation

struct ComposerView: View {
    @Environment(\.dismiss) private var dismiss
    let onPosted: () async -> Void

    @State private var body_ = ""
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var attachments: [(data: Data, filename: String, mime: String, isVideo: Bool)] = []
    @State private var audience = "PUBLIC"
    @State private var isPosting = false
    @State private var errorMessage: String?

    private let audiences = [("PUBLIC", "Everyone"), ("FOLLOWERS", "Followers"), ("FRIENDS", "Friends")]

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.navy950.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        TextEditor(text: $body_)
                            .frame(minHeight: 120)
                            .scrollContentBackground(.hidden)
                            .padding(10)
                            .background(Theme.navy900)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(alignment: .topLeading) {
                                if body_.isEmpty {
                                    Text("What's happening?")
                                        .foregroundStyle(Theme.slate400)
                                        .padding(16)
                                        .allowsHitTesting(false)
                                }
                            }

                        if !attachments.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(Array(attachments.enumerated()), id: \.offset) { i, item in
                                        ZStack(alignment: .topTrailing) {
                                            Group {
                                                if item.isVideo {
                                                    ZStack {
                                                        Theme.navy800
                                                        Image(systemName: "play.circle.fill")
                                                            .font(.system(size: 24))
                                                            .foregroundStyle(Theme.cyan400)
                                                    }
                                                } else if let uiImage = UIImage(data: item.data) {
                                                    Image(uiImage: uiImage).resizable().aspectRatio(contentMode: .fill)
                                                }
                                            }
                                            .frame(width: 76, height: 76)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))

                                            Button {
                                                attachments.remove(at: i)
                                            } label: {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundStyle(.white, Theme.danger)
                                            }
                                            .padding(3)
                                        }
                                    }
                                }
                            }
                        }

                        PhotosPicker(selection: $selectedItems, maxSelectionCount: 10,
                                     matching: .any(of: [.images, .videos])) {
                            Label("Add photos or video", systemImage: "photo.on.rectangle.angled")
                                .font(.system(size: 14))
                                .foregroundStyle(Theme.cyan300)
                        }

                        Picker("Audience", selection: $audience) {
                            ForEach(audiences, id: \.0) { Text($0.1).tag($0.0) }
                        }
                        .pickerStyle(.segmented)

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.danger)
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("New post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.tint(Theme.slate400)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isPosting ? "Posting…" : "Post") { Task { await submit() } }
                        .tint(Theme.cyan400)
                        .disabled(isPosting || (body_.isEmpty && attachments.isEmpty))
                }
            }
            .onChange(of: selectedItems) { _, newItems in
                Task { await loadAttachments(newItems) }
            }
        }
    }

    private func loadAttachments(_ items: [PhotosPickerItem]) async {
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
            // supportedContentTypes tells us image vs video reliably;
            // guessing from the bytes is fragile across formats.
            let isVideo = item.supportedContentTypes.contains { $0.conforms(to: .movie) }
            let ext = isVideo ? "mov" : "jpg"
            let mime = isVideo ? "video/quicktime" : "image/jpeg"
            attachments.append((data, "upload-\(UUID().uuidString).\(ext)", mime, isVideo))
        }
        selectedItems = []
    }

    private func submit() async {
        isPosting = true
        errorMessage = nil
        do {
            let files = attachments.map {
                (name: "media", filename: $0.filename, mimeType: $0.mime, data: $0.data)
            }
            _ = try await APIClient.shared.upload(
                "/api/posts",
                fields: ["body": body_, "audience": audience],
                files: files,
                as: EmptyResponse.self
            )
            await onPosted()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isPosting = false
    }
}
