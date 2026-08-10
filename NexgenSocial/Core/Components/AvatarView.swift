import SwiftUI

struct AvatarView: View {
    let url: String?
    let seed: String
    var size: CGFloat = 40

    var body: some View {
        AsyncImage(url: APIClient.mediaURL(url)) { phase in
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
