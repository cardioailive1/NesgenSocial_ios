import SwiftUI
import ImageIO
import UIKit

/// Decoded, downsampled images, kept in memory and reused.
///
/// `AsyncImage` caches nothing but bytes: the same photo scrolled off and
/// back on is decoded again from scratch, at the file's own pixel size. A
/// 4000x3000 upload drawn in a 300 pt box is a ~48 MB bitmap for something
/// that needs under 1 MB, which is both the memory spike and the dropped
/// frame when a feed is scrolled quickly.
///
/// Downsampling happens through `CGImageSource`, which decodes straight to
/// the requested size instead of decoding full-size and then shrinking.
enum ImageCache {
    private static let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        // Cost is counted in bytes below, so this is a real memory ceiling
        // rather than an object count. iOS evicts it under pressure anyway.
        cache.totalCostLimit = 64 * 1024 * 1024
        return cache
    }()

    /// Size is part of the key: an avatar and a feed photo of the same URL
    /// are different bitmaps, and the small one must not satisfy the large.
    private static func key(_ url: URL, _ maxPixel: CGFloat) -> NSString {
        "\(url.absoluteString)|\(Int(maxPixel))" as NSString
    }

    /// Synchronous hit, so a cell that scrolls back on draws its image in the
    /// same frame instead of flashing a spinner.
    static func cached(_ url: URL, maxPixel: CGFloat) -> UIImage? {
        cache.object(forKey: key(url, maxPixel))
    }

    static func image(for url: URL, maxPixel: CGFloat) async throws -> UIImage {
        if let hit = cached(url, maxPixel: maxPixel) { return hit }

        // `URLSession.shared` carries `URLCache.shared`, so the bytes are
        // reused across launches; this cache holds the decoded result.
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let image = downsample(data, maxPixel: maxPixel) else {
            throw URLError(.cannotDecodeContentData)
        }
        cache.setObject(image, forKey: key(url, maxPixel), cost: image.byteCount)
        return image
    }

    private static func downsample(_ data: Data, maxPixel: CGFloat) -> UIImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else {
            return nil
        }
        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            // Honour EXIF orientation, or portrait photos come out sideways.
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ] as [CFString: Any] as CFDictionary

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
}

private extension UIImage {
    var byteCount: Int {
        guard let cgImage else { return 1 }
        return cgImage.bytesPerRow * cgImage.height
    }
}

enum CachedImagePhase {
    case loading
    case success(Image)
    case failure
}

/// `AsyncImage`'s shape, backed by `ImageCache`.
///
/// Deliberately the same phase-switch API, so call sites read the same and
/// swapping one for the other is a one-word change.
struct CachedImage<Content: View>: View {
    let url: URL?
    /// The longest edge, in pixels, the image will ever be drawn at. Points
    /// times screen scale — passing points here makes everything blurry.
    var maxPixelSize: CGFloat = 1400
    @ViewBuilder let content: (CachedImagePhase) -> Content

    @State private var loaded: UIImage?
    @State private var failed = false

    /// Checked on every evaluation rather than only in `task`: a cell coming
    /// back on screen has its image already and should never show a spinner.
    private var available: UIImage? {
        loaded ?? url.flatMap { ImageCache.cached($0, maxPixel: maxPixelSize) }
    }

    private var phase: CachedImagePhase {
        if let available { return .success(Image(uiImage: available)) }
        return failed ? .failure : .loading
    }

    var body: some View {
        content(phase)
            .task(id: url) { await load() }
    }

    private func load() async {
        guard let url, available == nil else { return }
        failed = false
        do {
            loaded = try await ImageCache.image(for: url, maxPixel: maxPixelSize)
        } catch {
            guard !Task.isCancelled else { return }
            failed = true
        }
    }
}
