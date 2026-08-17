import XCTest
@testable import NexgenSocial

/// Both token kinds have to carry the device's identity: without `bundleId`
/// and `environment` the server stores the device against a defaulted APNs
/// host and the push silently never arrives. Nothing on the device can catch
/// that, so it is checked here.
final class PushSubscriptionServiceTests: XCTestCase {

    override func tearDown() {
        StubAPI.restore()
        super.tearDown()
    }

    func testAPNsSubscriptionSendsTheFullDeviceIdentity() async throws {
        let body = try await captureBody {
            try await PushSubscriptionService.subscribeAPNs(deviceToken: "abcdef")
        }

        XCTAssertEqual(body["deviceToken"] as? String, "abcdef")
        XCTAssertEqual(body["platform"] as? String, "ios")
        XCTAssertEqual(body["bundleId"] as? String, Bundle.main.bundleIdentifier)
        XCTAssertNotNil(body["environment"])
    }

    func testVoIPSubscriptionSendsTheSameIdentityUnderItsOwnKey() async throws {
        let body = try await captureBody {
            try await PushSubscriptionService.subscribeVoIP(token: "123456")
        }

        XCTAssertEqual(body["voipToken"] as? String, "123456")
        XCTAssertNil(body["deviceToken"], "a VoIP token is not an APNs token")
        XCTAssertEqual(body["platform"] as? String, "ios")
        XCTAssertEqual(body["bundleId"] as? String, Bundle.main.bundleIdentifier)
    }

    // MARK: -

    /// Runs `work` against the stub and returns the JSON body it sent.
    ///
    /// `URLProtocol` strips `httpBody` from the request it hands the handler,
    /// leaving only `httpBodyStream`, so the body is read back off the stream.
    private func captureBody(_ work: () async throws -> Void) async throws -> [String: Any] {
        let box = BodyBox()
        StubAPI.install { request in
            box.data = request.bodyData
            return (200, Data("{}".utf8))
        }
        try await work()

        let data = try XCTUnwrap(box.data, "no request was sent")
        return try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private final class BodyBox: @unchecked Sendable { var data: Data? }
}

private extension URLRequest {
    var bodyData: Data? {
        if let httpBody { return httpBody }
        guard let stream = httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        let size = 4096
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: size)
        defer { buffer.deallocate() }
        while stream.hasBytesAvailable {
            let read = stream.read(buffer, maxLength: size)
            if read <= 0 { break }
            data.append(buffer, count: read)
        }
        return data
    }
}
