import SwiftUI

struct RootView: View {
    @EnvironmentObject var session: AuthSession
    @EnvironmentObject var callService: CallService

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
        .fullScreenCover(isPresented: $callService.isCallActive) {
            if let call = callService.activeCall {
                CallView(call: call)
            }
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

            ExploreView()
                .tabItem { Label("Explore", systemImage: "safari.fill") }
                .tag(2)

            MessagesView()
                .tabItem { Label("Messages", systemImage: "bubble.left.fill") }
                .tag(3)

            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.fill") }
                .tag(4)
        }
        .tint(Theme.cyan400)
        .onReceive(NotificationCenter.default.publisher(for: .openDeepLink)) { note in
            guard let path = note.object as? String else { return }
            if path.contains("/messages") { selectedTab = 3 }
            else if path.contains("/reels") { selectedTab = 1 }
        }
    }
}
