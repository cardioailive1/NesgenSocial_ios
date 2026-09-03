import Foundation
import SwiftUI

/// App-wide authentication state.
@MainActor
final class AuthSession: ObservableObject {
    @Published var currentUser: User?
    @Published var isLoading = true
    @Published var errorMessage: String?

    var isSignedIn: Bool { currentUser != nil }

    /// Restores a previous session on launch. A stored token might be
    /// expired or revoked, so it's verified against the server rather than
    /// trusted -- otherwise the app shows a signed-in UI that fails on
    /// every request.
    func restore() async {
        isLoading = true
        defer { isLoading = false }

        guard await APIClient.shared.currentToken() != nil else {
            currentUser = nil
            return
        }
        do {
            currentUser = try await AuthService.me()
            await PushService.shared.registerIfAuthorized()
        } catch {
            await APIClient.shared.setToken(nil)
            currentUser = nil
        }
    }

    /// Takes an email *or* a username -- the server matches either, and the
    /// body key has to be `emailOrUsername` or it rejects the request as
    /// missing credentials.
    func signIn(emailOrUsername: String, password: String) async {
        await authenticate {
            try await AuthService.login(emailOrUsername: emailOrUsername, password: password)
        }
    }

    func signUp(email: String, username: String, displayName: String,
                password: String, acceptedTerms: Bool,
                inviteToken: String? = nil) async {
        errorMessage = nil
        guard acceptedTerms else {
            errorMessage = "You must accept the Terms of Use and Privacy Policy."
            return
        }
        await authenticate {
            var body: [String: Any] = [
                "email": email,
                "username": username,
                "displayName": displayName,
                "password": password,
                "acceptedTerms": true,
                "policyVersion": AppConfig.policyVersion,
            ]
            // Auto-friends the inviter on the server side.
            if let inviteToken, !inviteToken.isEmpty { body["inviteToken"] = inviteToken }
            return try await AuthService.register(body)
        }
    }

    func signOut() async {
        await PushService.shared.unregister()
        await APIClient.shared.setToken(nil)
        currentUser = nil
    }

    /// Deletes the account server-side, then tears down the local session the
    /// same way a sign-out does. The local state is only cleared once the
    /// server confirms, so a failed delete leaves the person signed in with
    /// an error rather than locked out of an account that still exists.
    func deleteAccount() async -> Bool {
        errorMessage = nil
        do {
            try await ProfileService.deleteAccount()
            await signOut()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// Sign-in and sign-up differ only in the request they make; everything
    /// after -- storing the token, publishing the user, registering for push,
    /// surfacing the error -- is identical and lives here once.
    private func authenticate(_ request: () async throws -> AuthResponse) async {
        errorMessage = nil
        do {
            let response = try await request()
            await APIClient.shared.setToken(response.token)
            currentUser = response.user
            await PushService.shared.registerIfAuthorized()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

enum AppConfig {
    static let policyVersion = "2026-07-30"
    static let websiteURL = "https://nexgensocialnet.com"
    static let privacyURL = "https://nexgensocialnet.com/legal/privacy"
    static let termsURL = "https://nexgensocialnet.com/legal/terms"
}
