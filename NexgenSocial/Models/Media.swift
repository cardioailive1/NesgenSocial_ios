import Foundation

// Named `MediaAssetKind`, not `MediaKind`: Mediasoup exports its own
// `MediaKind` (audio/video), and the collision silently breaks delegate
// conformance in any file that imports both.
enum MediaAssetKind: String, Codable {
    case photo = "PHOTO"
    case video = "VIDEO"
}

struct MediaItem: Codable, Identifiable, Hashable {
    let id: String
    let url: String
    let kind: MediaAssetKind
    var position: Int?
    var caption: String?
}
