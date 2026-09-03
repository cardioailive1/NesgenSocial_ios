import SwiftUI
import PhotosUI

struct ReelComposerView: View {
    @Environment(\.dismiss) private var dismiss
    let onPosted: () async -> Void

    @StateObject private var model = ReelComposerViewModel()
    @State private var selectedItem: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.navy950.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        PhotosPicker(selection: $selectedItem, matching: .videos) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12).fill(Theme.navy900)

                                if let thumbnail = model.thumbnail {
                                    Image(uiImage: thumbnail)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                } else {
                                    VStack(spacing: 8) {
                                        Image(systemName: "video.badge.plus")
                                            .font(.system(size: 34))
                                        Text(model.videoData == nil ? "Choose a video" : "Change video")
                                            .font(.system(size: 14))
                                    }
                                    .foregroundStyle(Theme.cyan300)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .aspectRatio(9.0 / 16.0, contentMode: .fit)
                        }

                        if model.durationSec > 0 {
                            Text("\(Int(model.durationSec))s")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(Theme.slate400)
                        }

                        TextEditor(text: $model.caption)
                            .frame(minHeight: 90)
                            .scrollContentBackground(.hidden)
                            .padding(10)
                            .background(Theme.navy900)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(alignment: .topLeading) {
                                if model.caption.isEmpty {
                                    Text("Add a caption. #hashtags work here.")
                                        .foregroundStyle(Theme.slate400)
                                        .padding(16)
                                        .allowsHitTesting(false)
                                }
                            }

                        ErrorBanner(message: model.errorMessage)
                    }
                    .padding(16)
                }
            }
            .navigationTitle("New reel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.tint(Theme.slate400)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(model.isPosting ? "Posting…" : "Share") {
                        Task {
                            if await model.submit() {
                                await onPosted()
                                dismiss()
                            }
                        }
                    }
                    .tint(Theme.cyan400)
                    .disabled(model.isPosting || !model.canPost)
                }
            }
            .onChange(of: selectedItem) { _, item in
                Task { await model.pick(item) }
            }
        }
    }
}
