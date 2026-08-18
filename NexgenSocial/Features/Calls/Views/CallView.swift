import SwiftUI
import AVFoundation
import WebRTC

/// In-call UI. Media transport runs through WebRTC against the same
/// mediasoup SFU the web app uses; CallKit owns the incoming-call
/// experience and the audio session.
struct CallView: View {
    let call: Call
    @EnvironmentObject var callService: CallService
    @EnvironmentObject var session: AuthSession
    @ObservedObject private var webRTC = WebRTCManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var isMuted = false
    @State private var isCameraOff = false
    @State private var permissionProblem: String?

    private var other: User? {
        // Whichever party isn't us. On an answered incoming call the record
        // carries both parties, so picking `callee` blindly showed the user
        // their own name and avatar. Falls back to caller so the screen never
        // renders nameless.
        let me = session.currentUser?.id
        if me == call.calleeId { return call.caller ?? call.callee }
        return call.callee ?? call.caller
    }

    var body: some View {
        ZStack {
            Theme.navy950.ignoresSafeArea()

            if let remote = webRTC.remoteVideoTrack {
                VideoTrackView(track: remote)
                    .ignoresSafeArea()
            }

            VStack(spacing: 18) {
                Spacer()

                // Once the other side's video arrives it replaces the
                // placeholder entirely; the avatar is what a voice call and
                // a not-yet-connected video call both show.
                if webRTC.remoteVideoTrack == nil {
                    AvatarView(url: other?.avatarUrl, seed: other?.username ?? "?", size: 96)

                    Text(other?.displayName ?? "Call")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                }

                // Counts talk time, not time since dialling: an outgoing call
                // is on screen while it rings, and a ringing call has no
                // duration yet.
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(timeString(at: context.date))
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundStyle(Theme.slate400)
                }

                // A media failure otherwise looks exactly like a call the
                // other side simply hasn't picked up.
                if let problem = permissionProblem {
                    Text(problem)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.danger)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)

                    Button("Open Settings") { MediaPermissions.openSettings() }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.cyan400)
                } else if let problem = webRTC.lastError {
                    Text(problem)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.danger)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Spacer()

                HStack(spacing: 26) {
                    CallButton(icon: isMuted ? "mic.slash.fill" : "mic.fill",
                               label: isMuted ? "Unmute" : "Mute",
                               background: Theme.navy800) {
                        isMuted.toggle()
                        WebRTCManager.shared.setMuted(isMuted)
                    }

                    if call.kind == "VIDEO" {
                        CallButton(icon: isCameraOff ? "video.slash.fill" : "video.fill",
                                   label: isCameraOff ? "Camera on" : "Camera off",
                                   background: Theme.navy800) {
                            isCameraOff.toggle()
                            WebRTCManager.shared.setCameraEnabled(!isCameraOff)
                        }
                    }

                    CallButton(icon: "phone.down.fill", label: "End",
                               background: Theme.danger) {
                        callService.endCall()
                        dismiss()
                    }
                }
                .padding(.bottom, 50)
            }

            if let local = webRTC.localVideoTrack, !isCameraOff {
                VStack {
                    HStack {
                        Spacer()
                        VideoTrackView(track: local)
                            .frame(width: 104, height: 156)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(Theme.line, lineWidth: 1)
                            )
                            .padding(.trailing, 16)
                    }
                    Spacer()
                }
                .padding(.top, 16)
            }
        }
        .task {
            let video = call.kind == "VIDEO"
            // Re-checked here rather than trusted from sign-in: access can be
            // revoked in Settings at any time, and connecting without it
            // leaves the other side on a silent, frozen call.
            permissionProblem = MediaPermissions.message(video: video)
            guard permissionProblem == nil else { return }
            await WebRTCManager.shared.connect(callId: call.id, video: video)
        }
        .onDisappear { WebRTCManager.shared.disconnect() }
    }

    private func timeString(at now: Date) -> String {
        guard let start = callService.connectedAt else { return "Ringing…" }
        let seconds = max(0, Int(now.timeIntervalSince(start)))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}

/// Renders a WebRTC video track. `RTCMTLVideoView` is the Metal-backed
/// renderer; the older `RTCEAGLVideoView` is deprecated and drops frames on
/// modern devices.
struct VideoTrackView: UIViewRepresentable {
    let track: RTCVideoTrack

    func makeUIView(context: Context) -> RTCMTLVideoView {
        let view = RTCMTLVideoView()
        view.videoContentMode = .scaleAspectFill
        track.add(view)
        return view
    }

    func updateUIView(_ view: RTCMTLVideoView, context: Context) {}

    static func dismantleUIView(_ view: RTCMTLVideoView, coordinator: ()) {
        // Without this the track keeps a strong reference to a view that is
        // no longer on screen, and the renderer runs for the rest of the
        // call.
        view.removeFromSuperview()
    }
}

struct CallButton: View {
    let icon: String
    let label: String
    let background: Color
    let action: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            Button(action: action) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundStyle(.white)
                    .frame(width: 62, height: 62)
                    .background(background)
                    .clipShape(Circle())
            }
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Theme.slate400)
        }
    }
}
