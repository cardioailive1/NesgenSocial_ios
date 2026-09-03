import Foundation
import AVFoundation
import UIKit
import SwiftUI
import PhotosUI

@MainActor
final class ReelComposerViewModel: ObservableObject {
    @Published var caption = ""
    @Published private(set) var videoData: Data?
    @Published private(set) var thumbnail: UIImage?
    @Published private(set) var durationSec: Double = 0
    @Published private(set) var isPosting = false
    @Published var errorMessage: String?

    var canPost: Bool { videoData != nil }

    /// The picker hands back bytes, but `AVAsset` needs a URL, so the clip is
    /// written to a temp file to read its duration and first frame.
    func pick(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        errorMessage = nil
        guard let data = try? await item.loadTransferable(type: Data.self) else {
            errorMessage = "Couldn't read that video."
            return
        }
        videoData = data

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("reel-\(UUID().uuidString).mov")
        defer { try? FileManager.default.removeItem(at: url) }
        guard (try? data.write(to: url)) != nil else { return }

        let asset = AVURLAsset(url: url)
        durationSec = (try? await asset.load(.duration).seconds) ?? 0

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        if let cgImage = try? await generator.image(at: .zero).image {
            thumbnail = UIImage(cgImage: cgImage)
        }
    }

    func clear() {
        videoData = nil
        thumbnail = nil
        durationSec = 0
    }

    /// Returns true when the reel went through, so the view knows whether to
    /// dismiss.
    func submit() async -> Bool {
        guard let videoData, !isPosting else { return false }
        isPosting = true
        errorMessage = nil
        defer { isPosting = false }
        do {
            _ = try await ReelsService.create(caption: caption,
                                              durationSec: durationSec,
                                              video: videoData,
                                              // JPEG rather than PNG: the
                                              // thumbnail rides in the same
                                              // request as the video.
                                              thumbnail: thumbnail?.jpegData(compressionQuality: 0.8))
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
