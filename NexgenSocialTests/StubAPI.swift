import Foundation
@testable import NexgenSocial

/// Serves canned responses to the app's own networking, so view models can be
/// exercised without a server — G7 in `FEATURE_AUDIT.md`.
///
/// It works by swapping `APIClient.shared` for one built on a `URLSession`
/// whose only protocol handler is `StubURLProtocol`. Nothing in the app
/// changes: services keep calling `APIClient.shared` exactly as they do in
/// production, which is the point — a fake service layer would prove the fake
/// works, not the app.
enum StubAPI {

    /// Points the app at the stub for the duration of one test. Call
    /// `restore()` in `tearDown`.
    ///
    /// `handler` receives every request the app makes and answers with a
    /// status code and a body.
    static func install(_ handler: @escaping (URLRequest) -> (Int, Data)) {
        StubURLProtocol.handler = handler
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        APIClient.shared = APIClient(session: URLSession(configuration: config))
    }

    /// Answers every request with the same JSON and status.
    static func install(json: String, status: Int = 200) {
        install { _ in (status, Data(json.utf8)) }
    }

    static func restore() {
        StubURLProtocol.handler = nil
        APIClient.shared = APIClient()
    }
}

final class StubURLProtocol: URLProtocol {
    /// Set through `StubAPI` only. Tests are serial, so a single static is
    /// enough — no queue, no per-instance registry.
    nonisolated(unsafe) static var handler: ((URLRequest) -> (Int, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        let (status, data) = handler(request)
        let response = HTTPURLResponse(url: request.url!,
                                       statusCode: status,
                                       httpVersion: "HTTP/1.1",
                                       headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
