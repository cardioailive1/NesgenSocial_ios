import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var session: AuthSession
    @State private var showSignOutConfirm = false
    @State private var pushEnabled = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.navy950.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        VStack(spacing: 10) {
                            AvatarView(url: session.currentUser?.avatarUrl,
                                       seed: session.currentUser?.username ?? "?", size: 84)
                            Text(session.currentUser?.displayName ?? "")
                                .font(.system(size: 20, weight: .semibold)).foregroundStyle(.white)
                            Text("@\(session.currentUser?.username ?? "")")
                                .font(.system(size: 13)).foregroundStyle(Theme.slate400)
                            if let bio = session.currentUser?.bio, !bio.isEmpty {
                                Text(bio)
                                    .font(.system(size: 13)).foregroundStyle(Theme.slate300)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(20)
                        .card()

                        VStack(spacing: 0) {
                            Toggle(isOn: $pushEnabled) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Call & message notifications")
                                        .font(.system(size: 14)).foregroundStyle(.white)
                                    Text("Ring even when the app is closed")
                                        .font(.system(size: 11)).foregroundStyle(Theme.slate400)
                                }
                            }
                            .tint(Theme.cyan400)
                            .padding(14)
                            .onChange(of: pushEnabled) { _, enabled in
                                if enabled { Task { pushEnabled = await PushService.shared.requestPermission() } }
                            }

                            Divider().background(Theme.line)

                            SettingsRow(icon: "square.and.arrow.up", title: "Export my data") {
                                // Opens in Safari: the export is a file
                                // download, which the browser handles better
                                // than an in-app view.
                                if let url = URL(string: APIClient.baseURL + "/api/users/me/export") {
                                    UIApplication.shared.open(url)
                                }
                            }
                            Divider().background(Theme.line)
                            SettingsRow(icon: "doc.text", title: "Privacy Policy") {
                                UIApplication.shared.open(URL(string: AppConfig.privacyURL)!)
                            }
                            Divider().background(Theme.line)
                            SettingsRow(icon: "doc.plaintext", title: "Terms of Use") {
                                UIApplication.shared.open(URL(string: AppConfig.termsURL)!)
                            }
                        }
                        .card()

                        Button("Sign out") { showSignOutConfirm = true }
                            .buttonStyle(GhostButtonStyle())
                            .padding(.top, 4)
                    }
                    .padding(14)
                }
            }
            .navigationTitle("Profile")
            .confirmationDialog("Sign out?", isPresented: $showSignOutConfirm) {
                Button("Sign out", role: .destructive) { Task { await session.signOut() } }
                Button("Cancel", role: .cancel) {}
            }
            .task { pushEnabled = PushService.shared.permissionGranted }
        }
    }
}

struct SettingsRow: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon).foregroundStyle(Theme.cyan400).frame(width: 22)
                Text(title).font(.system(size: 14)).foregroundStyle(.white)
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 12)).foregroundStyle(Theme.slate400)
            }
            .padding(14)
        }
    }
}
