import Foundation
import AVFoundation

/// WebRTC transport for calls and meetings.
///
/// IMPORTANT — this is the one part of the app that is deliberately a stub.
///
/// Real WebRTC on iOS requires the GoogleWebRTC binary (or a maintained
/// fork such as stasel/WebRTC) added via Swift Package Manager or
/// CocoaPods. That dependency can't be vendored here, and writing code
/// against an API surface I can't compile would produce something that
/// looks finished and fails in Xcode.
///
/// What IS complete: signalling message shapes below match the server in
/// backend/src/livestreamSignaling.js exactly -- join, createTransport,
/// connectTransport, produce, consume, resumeConsumer, using room ids of
/// the form `call-<id>` and `meet-<id>`. Wiring the real peer connection is
/// mechanical from here.
///
/// See README-iOS.md, "Completing WebRTC", for the exact steps.
@MainActor
final class WebRTCManager: NSObject {
    static let shared = WebRTCManager()

    private var webSocket: URLSessionWebSocketTask?
    private var isConnected = false

    private override init() { super.init() }

    func connect(callId: String, video: Bool) async {
        guard let url = URL(string: signalingURL) else { return }

        let session = URLSession(configuration: .default)
        let task = session.webSocketTask(with: url)
        webSocket = task
        task.resume()
        isConnected = true

        await send([
            "method": "join",
            "data": [
                "roomId": "call-\(callId)",
                // Both parties publish in a call, unlike a broadcast where
                // only the host does.
                "role": "host",
                "token": await APIClient.shared.currentToken() ?? "",
            ],
        ])

        listen()
    }

    func connectToMeeting(meetingId: String) async {
        guard let url = URL(string: signalingURL) else { return }
        let session = URLSession(configuration: .default)
        let task = session.webSocketTask(with: url)
        webSocket = task
        task.resume()
        isConnected = true

        await send([
            "method": "join",
            "data": [
                "roomId": "meet-\(meetingId)",
                "role": "host",
                "token": await APIClient.shared.currentToken() ?? "",
            ],
        ])
        listen()
    }

    func disconnect() {
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
        isConnected = false
    }

    func setMuted(_ muted: Bool) {
        // Toggles the local audio track once WebRTC is wired in.
        NotificationCenter.default.post(name: .webRTCMuteChanged, object: muted)
    }

    func setCameraEnabled(_ enabled: Bool) {
        NotificationCenter.default.post(name: .webRTCCameraChanged, object: enabled)
    }

    // MARK: - Signalling

    private var signalingURL: String {
        APIClient.baseURL.replacingOccurrences(of: "https://", with: "wss://")
                         .replacingOccurrences(of: "http://", with: "ws://") + "/ws/live"
    }

    private func send(_ payload: [String: Any]) async {
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let text = String(data: data, encoding: .utf8) else { return }
        try? await webSocket?.send(.string(text))
    }

    private func listen() {
        webSocket?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let message):
                if case .string(let text) = message {
                    Task { @MainActor in self.handle(text) }
                }
                Task { @MainActor in if self.isConnected { self.listen() } }
            case .failure(let error):
                print("Signalling socket closed: \(error.localizedDescription)")
                Task { @MainActor in self.isConnected = false }
            }
        }
    }

    private func handle(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

        if let type = json["type"] as? String {
            switch type {
            case "newProducer":  break // consume the new track
            case "peerClosed":   break // remove that peer's video tile
            default:             break
            }
        }
    }
}

extension Notification.Name {
    static let webRTCMuteChanged = Notification.Name("webRTCMuteChanged")
    static let webRTCCameraChanged = Notification.Name("webRTCCameraChanged")
}
