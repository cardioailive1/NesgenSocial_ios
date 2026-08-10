import Foundation

/// Anything with a viewer like state and a running tally.
///
/// Posts and reels both need the same optimistic behaviour: flip the heart the
/// instant it's tapped, and put it back if the request fails. Waiting on the
/// network before showing the change makes taps feel broken, and writing the
/// revert by hand at each call site is how the count and the icon drift apart.
protocol Likeable {
    var likedByViewer: Bool? { get set }
    var likeCount: Int? { get set }
}

extension Likeable {
    var isLiked: Bool { likedByViewer ?? false }

    /// Flips the like locally. Calling it twice restores the original state,
    /// which is exactly what the failure path needs.
    mutating func toggleLikeLocally() {
        let wasLiked = isLiked
        likedByViewer = !wasLiked
        likeCount = max(0, (likeCount ?? 0) + (wasLiked ? -1 : 1))
    }
}

extension Post: Likeable {}
extension Reel: Likeable {}
