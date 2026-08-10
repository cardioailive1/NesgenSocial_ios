import SwiftUI

/// `AsyncImage` gives up permanently on its first failure, which is how a
/// feed ends up with a broken-image box for a picture that loads perfectly
/// well when opened. Under a burst of parallel requests a timeout is common
/// and temporary, so this retries a couple of times before showing anything,
/// and offers a manual retry after that.
struct RetryingImage: View {
    let url: URL?
    private let maxAutomaticRetries = 2

    @State private var attempt = 0

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                // .fit, not .fill: cropping a portrait photo to a landscape
                // box hides part of the picture, which is exactly the bug
                // the web app had.
                image.resizable().aspectRatio(contentMode: .fit)
            case .failure:
                if attempt < maxAutomaticRetries {
                    ProgressView()
                        .tint(Theme.cyan400)
                        .task {
                            // Brief pause: retrying instantly just joins the
                            // same congestion that caused the failure.
                            try? await Task.sleep(for: .milliseconds(600))
                            attempt += 1
                        }
                } else {
                    Button { attempt += 1 } label: {
                        VStack(spacing: 6) {
                            Image(systemName: "arrow.clockwise")
                            Text("Tap to load").font(.system(size: 12))
                        }
                        .foregroundStyle(Theme.slate400)
                    }
                }
            default:
                ProgressView().tint(Theme.cyan400)
            }
        }
        .id(attempt)
    }
}
