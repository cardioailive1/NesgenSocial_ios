import WebRTC
import SwiftUI

struct RootView: View {
    @EnvironmentObject var session: AuthSession
    @EnvironmentObject var callService: CallService
    @Environment(\.scenePhase) private var scenePhase
    /// Meetings are presented here, not from the Meet tab: leaving the tab
    /// must not end the meeting, and minimising must keep its media alive.
    @ObservedObject private var meet = MeetSession.shared

    /// The call screen is presented by the call itself, minus the minimised
    /// case. Dismissing minimises rather than clearing `activeCall`, which
    /// would take the call down with it.
    private var presentedCall: Binding<Call?> {
        Binding(
            get: { callService.isMinimized ? nil : callService.activeCall },
            set: { if $0 == nil { callService.isMinimized = true } }
        )
    }

    private var presentedMeeting: Binding<Meeting?> {
        Binding(
            get: { meet.isMinimized ? nil : meet.activeMeeting },
            set: { if $0 == nil { meet.isMinimized = true } }
        )
    }

    var body: some View {
        ZStack {
            Theme.navy950.ignoresSafeArea()

            if session.isLoading {
                ProgressView().tint(Theme.cyan400)
            } else if session.isSignedIn {
                MainTabView()
            } else {
                AuthView()
            }
        }
        // Presented over whatever's on screen: a call shouldn't be
        // dismissible by navigating elsewhere.
        //
        // Driven by the call itself rather than a separate `isCallActive`
        // flag: answering sets the flag immediately but loads the call over
        // the network, so a flag-driven cover could present an empty screen
        // in the gap before `activeCall` arrives.
        .fullScreenCover(item: presentedCall) { call in
            CallView(call: call)
        }
        .fullScreenCover(item: presentedMeeting) { meeting in
            MeetingRoomView(meeting: meeting)
        }
        // Pushes the rest of the app down rather than floating over it, so
        // nothing is ever hidden behind the bar. A video call gets the
        // floating tile below instead -- a bar with no picture is a poor way
        // to minimise a call you are being seen on.
        .safeAreaInset(edge: .top) {
            if callService.isMinimized, let call = callService.activeCall,
               call.kind != "VIDEO" {
                OngoingCallBar()
            }
        }
        .overlay {
            if callService.isMinimized, let call = callService.activeCall,
               call.kind == "VIDEO" {
                FloatingCallTile()
            } else if meet.isMinimized, meet.activeMeeting != nil {
                FloatingVideoTile(track: WebRTCManager.shared.remoteTracks.values.first
                                      ?? WebRTCManager.shared.localVideoTrack,
                                  placeholder: "person.2.fill") {
                    meet.isMinimized = false
                }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                ScreenTimeTracker.shared.begin()
                PushService.shared.clearBadge()
            }
            else { ScreenTimeTracker.shared.end() }
        }
    }
}

struct MainTabView: View {
    @State private var selectedTab = 0
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView(selection: $selectedTab) {
            FeedView()
                .environment(\.isTabActive, selectedTab == 0)
                .tabItem { Label("Feed", systemImage: "house.fill") }
                .tag(0)

            ReelsView()
                .environment(\.isTabActive, selectedTab == 1)
                .tabItem { Label("Reels", systemImage: "play.rectangle.fill") }
                .tag(1)

            DiscoverView()
                .environment(\.isTabActive, selectedTab == 2)
                .tabItem { Label("Discover", systemImage: "safari.fill") }
                .tag(2)

            MessagesView()
                .environment(\.isTabActive, selectedTab == 3)
                .tabItem { Label("Messages", systemImage: "bubble.left.fill") }
                .tag(3)

            ProfileView()
                .environment(\.isTabActive, selectedTab == 4)
                .tabItem { Label("Profile", systemImage: "person.fill") }
                .tag(4)
        }
        .tint(Theme.cyan400)
        .task { await MediaPermissions.requestAll() }
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            await CallService.shared.pollForIncomingCalls()
        }
        .task {
            // Drains a notification tapped while the app was not running.
            if let link = PushService.shared.pendingDeepLink {
                PushService.shared.pendingDeepLink = nil
                if let destination = DeepLink.parse(link) { selectedTab = destination.tab }
                NotificationCenter.default.post(name: .openDeepLink, object: link)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openDeepLink)) { note in
            // Picks the tab. Going deeper than that is up to the tab: each
            // owns its own navigation stack, and `MessagesView` listens for
            // the same notification to open the conversation named in the
            // link. An unrecognised link leaves the user where they are.
            PushService.shared.pendingDeepLink = nil // handled live; don't replay it later
            guard let link = note.object as? String,
                  let destination = DeepLink.parse(link) else { return }
            selectedTab = destination.tab
        }
    }
}


/// The "tap to go back to your call" bar, shown while the call screen is
/// minimised. Deliberately the only way back: minimising is not hanging up,
/// and a call with no visible way to return to it reads as a bug.
struct OngoingCallBar: View {
    @EnvironmentObject var callService: CallService

    var body: some View {
        Button {
            callService.isMinimized = false
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "phone.fill")
                    .font(.system(size: 13, weight: .semibold))

                Text("Tap to return to call")
                    .font(.system(size: 14, weight: .semibold))

                Spacer()

                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(elapsed(at: context.date))
                        .font(.system(size: 13, design: .monospaced))
                }
            }
            .foregroundStyle(Theme.navy950)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity)
            .background(Theme.cyan400)
        }
    }

    private func elapsed(at now: Date) -> String {
        guard let start = callService.connectedAt else { return "Ringing…" }
        let seconds = max(0, Int(now.timeIntervalSince(start)))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}


/// Picture-in-picture for a minimised video call: the other side stays on
/// screen, draggable, while the rest of the app is used underneath. Tapping
/// it goes back to the full call screen.
///
/// This is in-app only. Keeping the video alive after the app is backgrounded
/// is `AVPictureInPictureController`, which needs WebRTC frames bridged into
/// an `AVSampleBufferDisplayLayer` -- a different and much larger piece of
/// work than this.
struct FloatingCallTile: View {
    @EnvironmentObject var callService: CallService
    @ObservedObject private var webRTC = WebRTCManager.shared

    var body: some View {
        FloatingVideoTile(track: webRTC.remoteVideoTrack, placeholder: "video.fill") {
            callService.isMinimized = false
        }
    }
}

/// The draggable tile itself. Calls and meetings both minimise to one of
/// these; only the picture and what a tap returns to differ.
struct FloatingVideoTile: View {
    let track: RTCVideoTrack?
    let placeholder: String
    let onTap: () -> Void

    @State private var center: CGPoint?

    private let size = CGSize(width: 108, height: 160)
    private let margin: CGFloat = 12

    var body: some View {
        GeometryReader { geo in
            tile
                .frame(width: size.width, height: size.height)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Theme.line, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.4), radius: 12, y: 4)
                .position(center ?? defaultCenter(in: geo.size))
                .gesture(
                    // ponytail: the tile jumps to the finger on grab rather
                    // than tracking the offset from where it was touched.
                    // Track the grab point too if it reads badly in the hand.
                    DragGesture()
                        .onChanged { center = $0.location }
                        .onEnded { center = clamped($0.location, in: geo.size) }
                )
                .onTapGesture(perform: onTap)
                .onChange(of: geo.size) { _, new in
                    // Rotation would otherwise leave it off screen.
                    if let point = center { center = clamped(point, in: new) }
                }
        }
        .ignoresSafeArea(.keyboard)
    }

    @ViewBuilder
    private var tile: some View {
        if let track {
            VideoTrackView(track: track)
        } else {
            // Video calls show the avatar until the far end's track arrives,
            // exactly as the full call screen does.
            Theme.navy800.overlay(
                Image(systemName: placeholder)
                    .font(.system(size: 24))
                    .foregroundStyle(Theme.slate400)
            )
        }
    }

    private func defaultCenter(in bounds: CGSize) -> CGPoint {
        CGPoint(x: bounds.width - size.width / 2 - margin,
                y: size.height / 2 + margin + 44)
    }

    private func clamped(_ point: CGPoint, in bounds: CGSize) -> CGPoint {
        let halfWidth = size.width / 2 + margin
        let halfHeight = size.height / 2 + margin
        return CGPoint(
            x: min(max(point.x, halfWidth), bounds.width - halfWidth),
            y: min(max(point.y, halfHeight), bounds.height - halfHeight)
        )
    }
}
