import SwiftUI

/// Hub for everything that doesn't earn its own tab. iOS collapses a sixth
/// tab into a system "More" list, which buries screens two taps deep and
/// can't be styled; one hub tab keeps the tab bar at five and the section
/// list readable.
struct DiscoverView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.navy950.ignoresSafeArea()

                List {
                    Section {
                        DiscoverRow(title: "People, jobs, marketplace",
                                    icon: "safari.fill") { ExploreView() }
                        DiscoverRow(title: "Meet", icon: "video.bubble.fill") { MeetView() }
                        DiscoverRow(title: "Live", icon: "dot.radiowaves.left.and.right") {
                            LivestreamsView()
                        }
                    }

                    Section {
                        DiscoverRow(title: "Friends", icon: "person.2.fill") { FriendsView() }
                        DiscoverRow(title: "Groups", icon: "person.3.fill") { GroupsView() }
                        DiscoverRow(title: "Circles", icon: "circle.hexagongrid.fill") {
                            CirclesView()
                        }
                        DiscoverRow(title: "Connections", icon: "link") { ConnectionsView() }
                        DiscoverRow(title: "Invite friends", icon: "envelope.fill") { InviteView() }
                    }

                    Section {
                        DiscoverRow(title: "Breaking news", icon: "newspaper.fill") { NewsView() }
                        DiscoverRow(title: "Newsrooms", icon: "building.columns.fill") {
                            NewsroomsView()
                        }
                        DiscoverRow(title: "Sports", icon: "sportscourt.fill") { SportsView() }
                        DiscoverRow(title: "Political", icon: "megaphone.fill") { PoliticalView() }
                        DiscoverRow(title: "Celebrity", icon: "sparkles") { CelebrityView() }
                    }

                    Section {
                        DiscoverRow(title: "Profile setup", icon: "person.text.rectangle.fill") {
                            ProfileSetupView()
                        }
                        DiscoverRow(title: "Places", icon: "mappin.and.ellipse") { PlacesView() }
                        DiscoverRow(title: "Your time here", icon: "hourglass") { WellbeingView() }
                    }

                    Section {
                        DiscoverRow(title: "Premium", icon: "star.fill") { PremiumView() }
                        DiscoverRow(title: "Ads", icon: "chart.bar.fill") { AdManagerView() }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Discover")
            .tint(Theme.cyan400)
        }
    }
}

struct DiscoverRow<Destination: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let destination: () -> Destination

    var body: some View {
        NavigationLink {
            destination()
        } label: {
            Label(title, systemImage: icon)
                .font(.system(size: 14))
                .foregroundStyle(.white)
        }
        .listRowBackground(Theme.navy900)
    }
}
