import Foundation

// Named `MediaAssetKind`, not `MediaKind`: Mediasoup exports its own
// `MediaKind` (audio/video), and the collision silently breaks delegate
// conformance in any file that imports both.
enum MediaAssetKind: String, Codable {
    case photo = "PHOTO"
    case video = "VIDEO"
    /// Anything that isn't playable or viewable inline -- a PDF, a document,
    /// an archive. The backend only stores PHOTO and VIDEO today, so nothing
    /// decodes to this yet; it exists so an added kind renders as a file card
    /// instead of failing the whole response.
    case file = "FILE"

    /// An unknown kind must not blow up a whole message list, which is what a
    /// plain `RawRepresentable` decode would do.
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = MediaAssetKind(rawValue: raw) ?? .file
    }
}

struct MediaItem: Codable, Identifiable, Hashable {
    let id: String
    let url: String
    let kind: MediaAssetKind
    var position: Int?
    var caption: String?
}
