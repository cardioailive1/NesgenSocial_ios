import SwiftUI
import UIKit

/// Everything that used to sit under the profile: notifications, data
/// export, the legal links, and sign out.
struct ProfileSettingsView: View {
    @EnvironmentObject var session: AuthSession
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var showSignOutConfirm = false
    @State private var showDeleteConfirm = false
    @State private var pushEnabled = false
    @State private var showLogShare = false
    @State private var showEmptyLogAlert = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.navy950.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        VStack(spacing: 0) {
                            // Bound through an explicit setter rather than
                            // `$pushEnabled` + `onChange`: `onChange` also
                            // fires when the toggle is synced from iOS on
                            // appear, which sent people straight to Settings
                            // without touching anything.
                            Toggle(isOn: Binding(get: { pushEnabled },
                                                 set: { pushToggled(to: $0) })) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Call & message notifications")
                                        .font(.system(size: 14)).foregroundStyle(.white)
                                    Text("Ring even when the app is closed")
                                        .font(.system(size: 11)).foregroundStyle(Theme.slate400)
                                }
                            }
                            .tint(Theme.cyan400)
                            .padding(14)

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

                        // Diagnostics only: push fails invisibly, so a tester
                        // needs a way to hand over what actually happened.
                        // Hidden entirely when `PushLog.isEnabled` is false.
                        if PushLog.isEnabled {
                            VStack(spacing: 0) {
                                SettingsRow(icon: "square.and.arrow.up.on.square",
                                            title: "Export push logs") {
                                    exportPushLog()
                                }
                                Divider().background(Theme.line)
                                SettingsRow(icon: "trash", title: "Clear push logs") {
                                    PushLog.clear()
                                }
                            }
                            .card()
                        }

                        Button("Sign out") { showSignOutConfirm = true }
                            .buttonStyle(GhostButtonStyle())
                            .padding(.top, 4)

                        Button("Delete account") { showDeleteConfirm = true }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.danger)
                            .padding(.top, 2)

                        if let errorMessage = session.errorMessage {
                            Text(errorMessage)
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.danger)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(14)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.foregroundStyle(Theme.cyan400)
                }
            }
            .confirmationDialog("Sign out?", isPresented: $showSignOutConfirm) {
                Button("Sign out", role: .destructive) { Task { await session.signOut() } }
                Button("Cancel", role: .cancel) {}
            }
            .confirmationDialog("Delete your account?", isPresented: $showDeleteConfirm,
                                titleVisibility: .visible) {
                Button("Delete account", role: .destructive) {
                    Task { if await session.deleteAccount() { dismiss() } }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Your posts, messages, and connections are removed permanently. This can't be undone.")
            }
            // Read from iOS every time, not from the cached flag: the person
            // may have changed it in Settings since the app last looked.
            .task { pushEnabled = await PushService.shared.isAuthorized }
            // Re-read on return from Settings, which is where the toggle
            // sends people -- otherwise the switch shows the old answer.
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                Task { pushEnabled = await PushService.shared.isAuthorized }
            }
            .sheet(isPresented: $showLogShare) {
                ShareSheet(items: [PushLog.fileURL])
            }
            .alert("No push log yet", isPresented: $showEmptyLogAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Nothing has been recorded. Sign out and back in to trigger push registration, then try again.")
            }
        }
    }
}

private extension ProfileSettingsView {
    /// Runs only when someone actually taps the toggle.
    ///
    /// iOS has no API to revoke notification permission, and it shows the
    /// system prompt exactly once -- so the first tap can ask, and every tap
    /// after that has to hand off to Settings or it silently does nothing.
    func pushToggled(to enabled: Bool) {
        Task {
            if enabled, await PushService.shared.canStillAsk {
                pushEnabled = await PushService.shared.requestPermission()
            } else {
                PushService.openSystemSettings()
                // Left as-is until the person comes back: the switch should
                // keep showing the real state, not the one they tapped.
                pushEnabled = await PushService.shared.isAuthorized
            }
        }
    }

    /// Shares the file itself rather than its text: AirDrop, Files and Mail
    /// all accept a `.txt` attachment, and a pasted wall of text loses the
    /// line breaks that make the log readable.
    func exportPushLog() {
        guard FileManager.default.fileExists(atPath: PushLog.fileURL.path) else {
            showEmptyLogAlert = true
            return
        }
        showLogShare = true
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
