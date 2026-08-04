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
            let response = try await APIClient.shared.get("/api/auth/me", as: MeResponse.self)
            currentUser = response.user
        } catch {
            await APIClient.shared.setToken(nil)
            currentUser = nil
        }
    }

    func signIn(email: String, password: String) async {
        errorMessage = nil
        do {
            let response = try await APIClient.shared.post(
                "/api/auth/login",
                body: ["email": email, "password": password],
                as: AuthResponse.self
            )
            await APIClient.shared.setToken(response.token)
            currentUser = response.user
            await PushService.shared.registerIfAuthorized()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signUp(email: String, username: String, displayName: String,
                password: String, acceptedTerms: Bool) async {
        errorMessage = nil
        guard acceptedTerms else {
            errorMessage = "You must accept the Terms of Use and Privacy Policy."
            return
        }
        do {
            let response = try await APIClient.shared.post(
                "/api/auth/register",
                body: [
                    "email": email,
                    "username": username,
                    "displayName": displayName,
                    "password": password,
                    "acceptedTerms": true,
                    "policyVersion": AppConfig.policyVersion,
                ],
                as: AuthResponse.self
            )
            await APIClient.shared.setToken(response.token)
            currentUser = response.user
            await PushService.shared.registerIfAuthorized()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signOut() async {
        await PushService.shared.unregister()
        await APIClient.shared.setToken(nil)
        currentUser = nil
    }
}

struct MeResponse: Codable { let user: User }

enum AppConfig {
    static let policyVersion = "2026-07-30"
    static let websiteURL = "https://nexgensocialnet.com"
    static let privacyURL = "https://nexgensocialnet.com/legal/privacy"
    static let termsURL = "https://nexgensocialnet.com/legal/terms"
}
