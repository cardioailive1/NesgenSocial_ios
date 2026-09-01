import SwiftUI
import AVFoundation
import AVKit
import WebRTC

/// In-call UI. Media transport runs through WebRTC against the same
/// mediasoup SFU the web app uses; CallKit owns the incoming-call
/// experience and the audio session.
struct CallView: View {
    let call: Call
    @EnvironmentObject var callService: CallService
    @EnvironmentObject var session: AuthSession
    @ObservedObject private var webRTC = WebRTCManager.shared

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
                if let notice = callService.endedNotice {
                    Text(notice)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Theme.slate400)
                } else {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text(timeString(at: context.date))
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundStyle(Theme.slate400)
                    }
                }

                // A media failure otherwise looks exactly like a call the
                // other side simply hasn't picked up.
                // A retry in flight isn't a failure yet -- the call is held,
                // so say so rather than showing the error that started it.
                if webRTC.isReconnecting {
                    HStack(spacing: 8) {
                        ProgressView().tint(Theme.slate400)
                        Text("Reconnecting…")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Theme.slate400)
                    }
                } else if let problem = permissionProblem ?? webRTC.lastError {
                    MediaErrorNotice(message: problem)
                }

                Spacer()

                // Five 62pt buttons on a video call overflow a 375pt screen
                // at the voice call's spacing.
                HStack(spacing: call.kind == "VIDEO" ? 10 : 20) {
                    CallButton(icon: webRTC.isMuted ? "mic.slash.fill" : "mic.fill",
                               label: webRTC.isMuted ? "Unmute" : "Mute",
                               background: Theme.navy800) {
                        webRTC.setMuted(!webRTC.isMuted)
                    }

                    AudioOutputButton()

                    if call.kind == "VIDEO" {
                        CallButton(icon: webRTC.isCameraEnabled ? "video.fill" : "video.slash.fill",
                                   label: webRTC.isCameraEnabled ? "Camera off" : "Camera on",
                                   background: Theme.navy800) {
                            webRTC.setCameraEnabled(!webRTC.isCameraEnabled)
                        }

                        CallButton(icon: "arrow.triangle.2.circlepath.camera.fill",
                                   label: "Flip", background: Theme.navy800) {
                            webRTC.switchCamera()
                        }
                        .disabled(!webRTC.isCameraEnabled)
                    }

                    CallButton(icon: "phone.down.fill", label: "End",
                               background: Theme.danger) {
                        // No `dismiss()`: the screen stays up showing why the
                        // call ended, and `activeCall` clearing takes it down.
                        callService.endCall()
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 50)
                .disabled(callService.endedNotice != nil)
            }

            VStack {
                HStack {
                    Button {
                        callService.isMinimized = true
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(Theme.navy800.opacity(0.8), in: Circle())
                    }
                    .padding(.leading, 16)
                    Spacer()
                }
                Spacer()
            }
            .padding(.top, 16)

            if let local = webRTC.localVideoTrack, webRTC.isCameraEnabled {
                VStack {
                    HStack {
                        Spacer()
                        // Mirrored, like every other self-view: the front
                        // camera's raw frames are laterally flipped from what
                        // the user sees in a mirror.
                        VideoTrackView(track: local, mirrored: webRTC.isUsingFrontCamera)
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
        // No `onDisappear` teardown: minimising dismisses this view while
        // the call is still up. `CallService` drops the media when the call
        // actually ends, which is the one path every ending goes through.
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
    var mirrored = false

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> RTCMTLVideoView {
        let view = RTCMTLVideoView()
        view.videoContentMode = .scaleAspectFill
        track.add(view)
        context.coordinator.track = track
        context.coordinator.view = view
        return view
    }

    func updateUIView(_ view: RTCMTLVideoView, context: Context) {
        // The track changes when a reconnect brings a new one, and the old
        // one would otherwise keep rendering into this view.
        if context.coordinator.track !== track {
            context.coordinator.track?.remove(view)
            track.add(view)
            context.coordinator.track = track
        }
        view.transform = mirrored ? CGAffineTransform(scaleX: -1, y: 1) : .identity
    }

    /// Detaching the renderer is what actually stops it. `removeFromSuperview`
    /// alone left the track holding the view, so it kept decoding frames into
    /// something off screen for the rest of the call.
    final class Coordinator {
        weak var track: RTCVideoTrack?
        weak var view: RTCMTLVideoView?

        deinit {
            guard let view else { return }
            track?.remove(view)
        }
    }
}

/// The audio output control.
///
/// Two behaviours behind one button, because which one is useful depends on
/// what is plugged in: with nothing but the phone itself there are only two
/// routes and a toggle is the fastest way between them, while with AirPods
/// or a headset connected a toggle cannot express the choice at all and the
/// system picker can.
struct AudioOutputButton: View {
    @EnvironmentObject var callService: CallService

    var body: some View {
        let route = callService.audioRoute

        if callService.hasExternalAudioRoute {
            CallButton(icon: route.icon, label: route.label, background: Theme.navy800) {}
                // The system route picker has no presentation API -- the view
                // *is* the button. Its own glyph is tinted away so ours shows
                // through underneath.
                // ponytail: swap for a custom sheet only if Apple ever ships
                // a way to present this directly.
                .overlay(RoutePicker().frame(width: 62, height: 62))
        } else {
            CallButton(icon: route.icon, label: route.label, background: Theme.navy800) {
                callService.setSpeaker(!route.isSpeaker)
            }
        }
    }
}

private struct RoutePicker: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let view = AVRoutePickerView()
        view.prioritizesVideoDevices = false
        view.tintColor = .clear
        view.activeTintColor = .clear
        return view
    }

    func updateUIView(_ view: AVRoutePickerView, context: Context) {}
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

/// A media failure with the way out of it. Access revoked in Settings is by
/// far the most common cause, and the button is useless noise for the rest,
/// so it only appears when access really is the problem.
struct MediaErrorNotice: View {
    let message: String

    var body: some View {
        VStack(spacing: 8) {
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(Theme.danger)
                .multilineTextAlignment(.center)

            if message.contains("Settings") {
                Button("Open Settings") { MediaPermissions.openSettings() }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.cyan400)
            }
        }
        .padding(.horizontal, 32)
    }
}
