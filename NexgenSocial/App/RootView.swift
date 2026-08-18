import SwiftUI

struct RootView: View {
    @EnvironmentObject var session: AuthSession
    @EnvironmentObject var callService: CallService
    @Environment(\.scenePhase) private var scenePhase

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
        .fullScreenCover(item: $callService.activeCall) { call in
            CallView(call: call)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { ScreenTimeTracker.shared.begin() }
            else { ScreenTimeTracker.shared.end() }
        }
    }
}

struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            FeedView()
                .tabItem { Label("Feed", systemImage: "house.fill") }
                .tag(0)

            ReelsView()
                .tabItem { Label("Reels", systemImage: "play.rectangle.fill") }
                .tag(1)

            DiscoverView()
                .tabItem { Label("Discover", systemImage: "safari.fill") }
                .tag(2)

            MessagesView()
                .tabItem { Label("Messages", systemImage: "bubble.left.fill") }
                .tag(3)

            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.fill") }
                .tag(4)
        }
        .tint(Theme.cyan400)
        .task { await MediaPermissions.requestAll() }
        .task { await CallService.shared.pollForIncomingCalls() }
        .onReceive(NotificationCenter.default.publisher(for: .openDeepLink)) { note in
            // Picks the tab. Going deeper than that is up to the tab: each
            // owns its own navigation stack, and `MessagesView` listens for
            // the same notification to open the conversation named in the
            // link. An unrecognised link leaves the user where they are.
            guard let link = note.object as? String,
                  let destination = DeepLink.parse(link) else { return }
            selectedTab = destination.tab
        }
    }
}
