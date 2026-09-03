import Foundation

enum AuthService {

    static func me() async throws -> User {
        try await APIClient.shared.get(APIEndpoints.Auth.me, as: MeResponse.self).user
    }

    static func login(emailOrUsername: String, password: String) async throws -> AuthResponse {
        try await APIClient.shared.post(APIEndpoints.Auth.login,
                                        body: ["emailOrUsername": emailOrUsername,
                                               "password": password],
                                        as: AuthResponse.self)
    }

    static func register(_ body: [String: Any]) async throws -> AuthResponse {
        try await APIClient.shared.post(APIEndpoints.Auth.register, body: body, as: AuthResponse.self)
    }

    /// Always succeeds for a well-formed address, whether or not the account
    /// exists — the server answers the same either way so the endpoint can't
    /// be used to find out who has an account here.
    static func forgotPassword(email: String) async throws {
        _ = try await APIClient.shared.post(APIEndpoints.Auth.forgotPassword,
                                            body: ["email": email],
                                            as: EmptyResponse.self)
    }

    private struct TokenCheck: Decodable { let valid: Bool }

    /// `false` for an expired, used, or made-up token, so the screen can say so
    /// before someone types a new password twice.
    static func resetTokenIsValid(_ token: String) async throws -> Bool {
        try await APIClient.shared.get(APIEndpoints.Auth.resetPasswordToken(token),
                                       as: TokenCheck.self).valid
    }

    static func resetPassword(token: String, password: String) async throws {
        _ = try await APIClient.shared.post(APIEndpoints.Auth.resetPassword,
                                            body: ["token": token, "password": password],
                                            as: EmptyResponse.self)
    }

    /// Pulls the token out of whatever someone pasted: the whole reset link,
    /// or the token on its own. The emailed link carries it as `?token=`.
    static func resetToken(in pasted: String) -> String? {
        token(in: pasted, named: "token")
    }

    /// Pulls the code out of a pasted invite link (`?ref=`) or a bare code.
    static func inviteToken(in pasted: String) -> String? {
        token(in: pasted, named: "ref")
    }

    /// Shared by both: a full link with the named query item, that link's
    /// last path component, or the bare token typed on its own.
    static func token(in pasted: String, named name: String) -> String? {
        let text = pasted.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        if let url = URL(string: text), url.scheme != nil {
            let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first { $0.name == name }?.value
            if let query, !query.isEmpty { return query }
            let last = url.lastPathComponent
            return last.isEmpty || last == "/" ? nil : last
        }
        return text.contains(" ") ? nil : text
    }
}
