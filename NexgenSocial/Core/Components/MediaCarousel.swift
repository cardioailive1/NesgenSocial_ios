import SwiftUI

/// Swipeable media, handling photo and video in one control.
struct MediaCarousel: View {
    let items: [MediaItem]
    @State private var index = 0

    var body: some View {
        PlaysWhenVisible { isVisible in
            Group {
                // `TabView(.page)` is a `UIPageViewController` underneath --
                // the heaviest thing in a feed card, and a lazy list builds
                // one per visible post. Most posts carry a single photo and
                // have nothing to page between, so they skip it entirely.
                if items.count == 1, let only = items.first {
                    // Sized by the picture's own aspect ratio, capped in
                    // height and centred across the card -- the same shape
                    // the web gallery uses. A fixed-height box left a
                    // portrait photo pinned to the left edge of the card.
                    page(for: only, isActive: isVisible)
                        .frame(maxWidth: .infinity, maxHeight: 420)
                } else {
                    TabView(selection: $index) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { i, item in
                            // Only the page being looked at, in a card that
                            // is actually on screen, gets a player.
                            page(for: item, isActive: isVisible && i == index)
                                .tag(i)
                        }
                    }
                    .tabViewStyle(.page)
                    // A pager cannot size itself to whichever page is
                    // showing, so a multi-item carousel keeps a fixed box.
                    .frame(height: 340)
                }
            }
            .frame(maxWidth: .infinity)
            .background(Theme.navy950)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    @ViewBuilder
    private func page(for item: MediaItem, isActive: Bool) -> some View {
        if item.kind == .video {
            // VideoSurface fills whatever it is given, so a lone video needs
            // a shape of its own; a photo brings one.
            VideoSurface(url: APIClient.mediaURL(item.url), isActive: isActive)
                .aspectRatio(items.count == 1 ? 16.0 / 9.0 : nil, contentMode: .fit)
        } else {
            RetryingImage(url: APIClient.mediaURL(item.url))
        }
    }
}
