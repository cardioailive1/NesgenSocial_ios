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
}
