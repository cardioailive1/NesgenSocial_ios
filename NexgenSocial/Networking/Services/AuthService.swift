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
}
