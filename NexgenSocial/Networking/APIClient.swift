import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case unauthorized
    case server(String)
    case decoding(String)
    case network(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:            return "Invalid request."
        case .unauthorized:          return "Your session expired. Please sign in again."
        case .server(let message):   return message
        case .decoding(let detail):  return "Unexpected response from the server. (\(detail))"
        case .network(let detail):   return detail
        }
    }
}

/// Single point of contact with the NexgenSocial API.
///
/// Deliberately an actor: token reads/writes and request building happen
/// from many screens concurrently, and this removes a whole class of data
/// races without scattering locks through the app.
actor APIClient {
    static let shared = APIClient()

    /// Change this to point at a local backend during development.
    static let baseURL = "https://nexgensocial-udp.fly.dev"

    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        // Uploads of video can be slow on cellular; a short resource
        // timeout would abort legitimate posts midway.
        config.timeoutIntervalForResource = 300
        config.waitsForConnectivity = true
        session = URLSession(configuration: config)
    }

    // MARK: - Token

    private var cachedToken: String?

    func setToken(_ token: String?) {
        cachedToken = token
        if let token {
            KeychainStore.save(token, for: "ngs_token")
        } else {
            KeychainStore.delete("ngs_token")
        }
    }

    func currentToken() -> String? {
        if let cachedToken { return cachedToken }
        cachedToken = KeychainStore.load("ngs_token")
        return cachedToken
    }

    // MARK: - Requests

    private func makeRequest(_ path: String, method: String = "GET", body: Data? = nil,
                             contentType: String? = "application/json") throws -> URLRequest {
        guard let url = URL(string: Self.baseURL + path) else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = method
        if let token = currentToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let contentType {
            request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        }
        request.httpBody = body
        return request
    }

    private func perform<T: Decodable>(_ request: URLRequest, as type: T.Type) async throws -> T {
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.network(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.network("No response from server.")
        }

        if http.statusCode == 401 {
            // Clear the dead token so the UI can route back to sign-in
            // instead of retrying with credentials that will never work.
            setToken(nil)
            throw APIError.unauthorized
        }

        guard (200..<300).contains(http.statusCode) else {
            // Surface the server's own message when it sends one -- it's
            // almost always more useful than a generic status code.
            if let apiError = try? JSONDecoder().decode(APIMessage.self, from: data),
               let message = apiError.error {
                throw APIError.server(message)
            }
            throw APIError.server("Request failed (\(http.statusCode)).")
        }

        if T.self == EmptyResponse.self, let empty = EmptyResponse() as? T {
            return empty
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError.decoding(String(describing: error))
        }
    }

    // MARK: - Verbs

    func get<T: Decodable>(_ path: String, as type: T.Type) async throws -> T {
        try await perform(makeRequest(path), as: type)
    }

    func post<T: Decodable>(_ path: String, body: [String: Any]? = nil, as type: T.Type) async throws -> T {
        let data = body.map { try? JSONSerialization.data(withJSONObject: $0) } ?? nil
        return try await perform(makeRequest(path, method: "POST", body: data ?? Data("{}".utf8)), as: type)
    }

    func patch<T: Decodable>(_ path: String, body: [String: Any]? = nil, as type: T.Type) async throws -> T {
        let data = body.map { try? JSONSerialization.data(withJSONObject: $0) } ?? nil
        return try await perform(makeRequest(path, method: "PATCH", body: data ?? Data("{}".utf8)), as: type)
    }

    func put<T: Decodable>(_ path: String, body: [String: Any]? = nil, as type: T.Type) async throws -> T {
        let data = body.map { try? JSONSerialization.data(withJSONObject: $0) } ?? nil
        return try await perform(makeRequest(path, method: "PUT", body: data ?? Data("{}".utf8)), as: type)
    }

    @discardableResult
    func delete(_ path: String) async throws -> EmptyResponse {
        try await perform(makeRequest(path, method: "DELETE"), as: EmptyResponse.self)
    }

    // MARK: - Multipart upload

    /// Uploads files alongside form fields. Built by hand rather than with a
    /// dependency, because the payload shape is simple and one fewer
    /// third-party package is one fewer thing to audit before App Review.
    func upload<T: Decodable>(_ path: String,
                              fields: [String: String] = [:],
                              files: [(name: String, filename: String, mimeType: String, data: Data)],
                              as type: T.Type) async throws -> T {
        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()

        func append(_ string: String) { body.append(Data(string.utf8)) }

        for (key, value) in fields {
            append("--\(boundary)\r\n")
            append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
            append("\(value)\r\n")
        }

        for file in files {
            append("--\(boundary)\r\n")
            append("Content-Disposition: form-data; name=\"\(file.name)\"; filename=\"\(file.filename)\"\r\n")
            append("Content-Type: \(file.mimeType)\r\n\r\n")
            body.append(file.data)
            append("\r\n")
        }
        append("--\(boundary)--\r\n")

        let request = try makeRequest(path, method: "POST", body: body,
                                      contentType: "multipart/form-data; boundary=\(boundary)")
        return try await perform(request, as: type)
    }

    /// Absolute URL for a media path returned by the API.
    nonisolated static func mediaURL(_ path: String?) -> URL? {
        guard let path, !path.isEmpty else { return nil }
        if path.hasPrefix("http") { return URL(string: path) }
        return URL(string: baseURL + path)
    }
}

struct EmptyResponse: Decodable {}
