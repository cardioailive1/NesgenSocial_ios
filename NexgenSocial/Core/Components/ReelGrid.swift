import SwiftUI

/// The three-column square grid the profile reels tab uses. Reels always
/// carry a poster frame, which is what makes a grid work for them and not
/// for posts -- posts here are mostly text, so those stayed a card list.
struct ReelGrid: View {
    let reels: [Reel]
    let onOpen: (Reel) -> Void

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 3),
                  spacing: 2) {
            ForEach(reels) { reel in
                Button { onOpen(reel) } label: {
                    GridTile(media: reel.thumbnailUrl.map {
                        MediaItem(id: reel.id, url: $0, kind: .photo, position: 0, caption: nil)
                    },
                             fallbackText: reel.caption,
                             badge: "play.fill")
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// One square. Kept private: `ReelGrid` is the only caller, and a tile on
/// its own has no meaning outside it.
private struct GridTile: View {
    let media: MediaItem?
    let fallbackText: String?
    let badge: String?

    var body: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fill)
            .overlay {
                if let url = APIClient.mediaURL(media?.url) {
                    CachedImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().aspectRatio(contentMode: .fill)
                        default:
                            Theme.navy800
                        }
                    }
                } else {
                    // A text-only post. Its opening line is the tile.
                    Text(fallbackText ?? "")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.slate300)
                        .lineLimit(5)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding(8)
                        .background(Theme.navy800)
                }
            }
            .overlay(alignment: .topTrailing) {
                if let badge, media != nil {
                    Image(systemName: badge)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .shadow(radius: 2)
                        .padding(6)
                }
            }
            .clipped()
            .contentShape(Rectangle())
    }
}
