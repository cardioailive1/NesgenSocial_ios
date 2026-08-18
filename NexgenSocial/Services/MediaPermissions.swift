import AVFoundation
import UIKit

/// Camera and microphone access, asked for once after sign-in and re-checked
/// before every call.
///
/// Asking at sign-in rather than at the first call means the system prompt
/// doesn't land on top of a ringing call, where a user tapping "Don't Allow"
/// to get back to the call screen permanently breaks calling.
enum MediaPermissions {
    static func status(_ media: AVMediaType) -> AVAuthorizationStatus {
        AVCaptureDevice.authorizationStatus(for: media)
    }

    /// Prompts for anything not yet decided. Already-denied media stays
    /// denied -- iOS only shows the system prompt once, after which the
    /// request returns false without any UI.
    static func request(_ media: AVMediaType) async -> Bool {
        switch status(media) {
        case .authorized: return true
        case .notDetermined: return await AVCaptureDevice.requestAccess(for: media)
        default: return false
        }
    }

    /// Asks for both at sign-in. Sequential, not concurrent: two system
    /// alerts queued at once show the second one only after the first is
    /// dismissed, and iOS drops it if the app is still presenting.
    static func requestAll() async {
        _ = await request(.audio)
        _ = await request(.video)
    }

    /// What's missing for a call of this kind, as a user-facing name, or nil
    /// when everything needed is granted.
    static func missing(video: Bool) -> String? {
        let needsMic = status(.audio) != .authorized
        let needsCamera = video && status(.video) != .authorized
        switch (needsMic, needsCamera) {
        case (true, true): return "Microphone and camera"
        case (true, false): return "Microphone"
        case (false, true): return "Camera"
        case (false, false): return nil
        }
    }

    static func message(video: Bool) -> String? {
        guard let missing = missing(video: video) else { return nil }
        return "\(missing) access is off. Go to Settings > Apps > NexgenSocial and give access."
    }

    static func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
