import SwiftUI
import PhotosUI

struct NewAdView: View {
    @Environment(\.dismiss) private var dismiss
    let onCreated: () async -> Void

    @StateObject private var model = NewAdViewModel()
    @State private var selectedItems: [PhotosPickerItem] = []

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.navy950.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Picker("Category", selection: $model.category) {
                            Text("General").tag("GENERAL")
                            Text("Business").tag("BUSINESS")
                            Text("Political").tag("POLITICAL")
                        }
                        .pickerStyle(.segmented)

                        if model.category == "POLITICAL" {
                            Text("Political ads carry a paid-for disclosure wherever they appear.")
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.slate400)
                        }

                        TextField("Headline", text: $model.headline).fieldStyle()
                        TextField("Body", text: $model.bodyText, axis: .vertical)
                            .lineLimit(3...6)
                            .fieldStyle()
                        TextField("Link (optional)", text: $model.targetUrl)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .fieldStyle()

                        PhotosPicker(selection: $selectedItems, maxSelectionCount: 5, matching: .any(of: [.images, .videos])) {
                            Label("Add media", systemImage: "photo.on.rectangle")
                                .font(.system(size: 13))
                        }
                        AttachmentStrip(attachments: $model.attachments)

                        ErrorBanner(message: model.errorMessage)

                        if model.created != nil {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Saved. It won't run until it's paid for.")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Theme.slate300)
                                Button("Pay now") { Task { await startCheckout() } }
                                    .buttonStyle(.borderedProminent)
                                    .tint(Theme.cyan400)
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .card()
                        }
                    }
                    .padding(14)
                }
            }
            .navigationTitle("New campaign")
            .navigationBarTitleDisplayMode(.inline)
            .tint(Theme.cyan400)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }.tint(Theme.slate400)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(model.isSaving ? "Saving…" : "Save") { Task { await save() } }
                        .disabled(!model.canSave)
                }
            }
            .onChange(of: selectedItems) { _, items in
                Task {
                    model.attachments += await AttachmentLoader.load(items)
                    selectedItems = []
                }
            }
        }
    }

    private func save() async {
        await model.save()
        if model.created != nil { await onCreated() }
    }

    private func startCheckout() async {
        guard let url = await model.checkoutURL() else { return }
        await UIApplication.shared.open(url)
        dismiss()
    }
}
