import SwiftUI

/// Swipeable media, handling photo and video in one control.
struct MediaCarousel: View {
    let items: [MediaItem]
    @State private var index = 0

    var body: some View {
        PlaysWhenVisible { isVisible in
            TabView(selection: $index) {
                ForEach(Array(items.enumerated()), id: \.element.id) { i, item in
                    Group {
                        if item.kind == .video {
                            // Only the page being looked at, in a card that
                            // is actually on screen, gets a player.
                            VideoSurface(url: APIClient.mediaURL(item.url),
                                         isActive: isVisible && i == index)
                        } else {
                            RetryingImage(url: APIClient.mediaURL(item.url))
                        }
                    }
                    .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: items.count > 1 ? .automatic : .never))
            .frame(height: 300)
            .background(Theme.navy950)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}
