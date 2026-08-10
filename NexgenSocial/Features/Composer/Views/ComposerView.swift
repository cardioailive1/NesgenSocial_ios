import SwiftUI
import PhotosUI

struct ComposerView: View {
    @Environment(\.dismiss) private var dismiss
    let onPosted: () async -> Void

    @StateObject private var model = ComposerViewModel()
    @State private var selectedItems: [PhotosPickerItem] = []

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.navy950.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        TextEditor(text: $model.text)
                            .frame(minHeight: 120)
                            .scrollContentBackground(.hidden)
                            .padding(10)
                            .background(Theme.navy900)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(alignment: .topLeading) {
                                if model.text.isEmpty {
                                    Text("What's happening?")
                                        .foregroundStyle(Theme.slate400)
                                        .padding(16)
                                        .allowsHitTesting(false)
                                }
                            }

                        if !model.attachments.isEmpty {
                            AttachmentStrip(attachments: $model.attachments)
                        }

                        PhotosPicker(selection: $selectedItems, maxSelectionCount: 10,
                                     matching: .any(of: [.images, .videos])) {
                            Label("Add photos or video", systemImage: "photo.on.rectangle.angled")
                                .font(.system(size: 14))
                                .foregroundStyle(Theme.cyan300)
                        }

                        Picker("Audience", selection: $model.audience) {
                            ForEach(ComposerViewModel.Audience.allCases, id: \.rawValue) {
                                Text($0.title).tag($0.rawValue)
                            }
                        }
                        .pickerStyle(.segmented)

                        if let errorMessage = model.errorMessage {
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
                    Button(model.isPosting ? "Posting…" : "Post") {
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
            .onChange(of: selectedItems) { _, newItems in
                Task {
                    await model.addAttachments(newItems)
                    selectedItems = []
                }
            }
        }
    }
}
