import SwiftUI

struct AvatarView: View {
    let url: String?
    let seed: String
    var size: CGFloat = 40

    @Environment(\.displayScale) private var displayScale

    var body: some View {
        // Decoded at the size it is drawn: an avatar is 40 pt, so the full
        // upload behind it is thousands of times more pixels than the circle
        // can show, and a feed draws dozens of them.
        CachedImage(url: APIClient.mediaURL(url),
                    maxPixelSize: size * displayScale) { phase in
            if case .success(let image) = phase {
                image.resizable().aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    Theme.navy800
                    Text(String(seed.prefix(1)).uppercased())
                        .font(.system(size: size * 0.42, weight: .semibold))
                        .foregroundStyle(Theme.cyan300)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(Theme.line, lineWidth: 1))
    }
}
