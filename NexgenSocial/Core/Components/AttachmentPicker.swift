import SwiftUI
import PhotosUI
import UIKit

/// One picked photo or video, already loaded into memory and ready to upload.
struct PickedAttachment: Identifiable {
    let id = UUID()
    let data: Data
    let filename: String
    let mimeType: String
    let isVideo: Bool
}

extension Array where Element == PickedAttachment {
    /// Shape the multipart `upload` helper expects. The backend reads the
    /// `media` field for both posts and messages.
    var uploadFiles: [(name: String, filename: String, mimeType: String, data: Data)] {
        map { (name: "media", filename: $0.filename, mimeType: $0.mimeType, data: $0.data) }
    }
}

enum AttachmentLoader {
    /// Loads picker selections into memory. Items that fail to load are
    /// skipped rather than failing the whole batch.
    static func load(_ items: [PhotosPickerItem]) async -> [PickedAttachment] {
        var loaded: [PickedAttachment] = []
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
            // supportedContentTypes tells us image vs video reliably;
            // guessing from the bytes is fragile across formats.
            let isVideo = item.supportedContentTypes.contains { $0.conforms(to: .movie) }
            loaded.append(PickedAttachment(
                data: data,
                filename: "upload-\(UUID().uuidString).\(isVideo ? "mov" : "jpg")",
                mimeType: isVideo ? "video/quicktime" : "image/jpeg",
                isVideo: isVideo
            ))
        }
        return loaded
    }
}

/// Horizontal strip of picked attachments with a remove button on each.
struct AttachmentStrip: View {
    @Binding var attachments: [PickedAttachment]
    var thumbnailSize: CGFloat = 76

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(attachments) { item in
                    ZStack(alignment: .topTrailing) {
                        Group {
                            if item.isVideo {
                                ZStack {
                                    Theme.navy800
                                    Image(systemName: "play.circle.fill")
                                        .font(.system(size: thumbnailSize / 3))
                                        .foregroundStyle(Theme.cyan400)
                                }
                            } else if let uiImage = UIImage(data: item.data) {
                                Image(uiImage: uiImage).resizable().aspectRatio(contentMode: .fill)
                            }
                        }
                        .frame(width: thumbnailSize, height: thumbnailSize)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                        Button {
                            attachments.removeAll { $0.id == item.id }
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
}
