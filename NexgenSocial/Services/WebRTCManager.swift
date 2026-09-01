import Foundation
import AVFoundation
import Mediasoup
import WebRTC

/// WebRTC transport for calls and meetings, speaking mediasoup's protocol
/// against `backend/src/livestreamSignaling.js`.
///
/// The server is an SFU, not a peer-to-peer mesh, so a bare
/// `RTCPeerConnection` cannot talk to it -- the signalling is mediasoup's
/// own (device capabilities, transports, producers, consumers). That is why
/// this goes through `Mediasoup-Client-Swift` rather than the raw WebRTC
/// framework alone.
///
/// Wire protocol, as the server actually implements it:
///   request       { reqId, method, data }
///   reply         { reqId, ok: true, data } | { reqId, ok: false, error }
///   notification  { notification, data }
///
/// Every value mediasoup-client takes is a JSON *string*, while the server
/// sends JSON *objects*, so parameters get re-serialised on the way through.
@MainActor
final class WebRTCManager: NSObject, ObservableObject {
    static let shared = WebRTCManager()

    /// Remote participant's video, published for the call UI to render.
    @Published private(set) var remoteVideoTrack: RTCVideoTrack?
    @Published private(set) var localVideoTrack: RTCVideoTrack?
    @Published private(set) var isConnected = false
    /// Media is down but a retry is in flight. A blip on the network -- a
    /// wifi-to-cellular hop, a lift -- used to drop the call outright; the
    /// call is held for `reconnectWindow` behind a "Reconnecting" banner
    /// instead.
    @Published private(set) var isReconnecting = false
    /// Mic and camera state live here rather than in the call screen: that
    /// screen is destroyed and rebuilt every time the call is minimised and
    /// restored, and its local flags came back false while the producers
    /// were still paused -- the buttons then lied and toggled backwards.
    @Published private(set) var isMuted = false
    @Published private(set) var isCameraEnabled = true
    @Published private(set) var isUsingFrontCamera = true
    /// Why media never came up, for the call screen to show. A silent
    /// failure here is indistinguishable from a call nobody answers.
    @Published private(set) var lastError: String?

    private var webSocket: URLSessionWebSocketTask?
    /// What to re-join with when the connection drops.
    private var lastJoin: (roomId: String, role: String, video: Bool, publish: Bool)?
    private var reconnect: Task<Void, Never>?
    private let reconnectWindow: TimeInterval = 15
    /// Keeps the signalling socket from being reaped mid-call. See
    /// `startKeepAlive`.
    private var keepAlive: Task<Void, Never>?

    private var device: Device?
    private var sendTransport: SendTransport?
    private var receiveTransport: ReceiveTransport?
    private var audioProducer: Producer?
    private var videoProducer: Producer?
    private var consumers: [String: Consumer] = [:]

    private var videoCapturer: RTCCameraVideoCapturer?

    private var sendHandler: SendTransportHandler?
    private var receiveHandler: ReceiveTransportHandler?

    /// Pending JSON-RPC requests, keyed by reqId. Without this the `join`
    /// reply carrying `rtpCapabilities` can never be matched to its request.
    private var pending: [String: CheckedContinuation<[String: Any], Error>] = [:]

    private static let factory: RTCPeerConnectionFactory = {
        RTCInitializeSSL()
        return RTCPeerConnectionFactory(
            encoderFactory: RTCDefaultVideoEncoderFactory(),
            decoderFactory: RTCDefaultVideoDecoderFactory()
        )
    }()

    private static var clientInitialized = false

    private override init() {
        super.init()
        // CallKit owns the audio session, so WebRTC must not activate one of
        // its own behind its back. Audio is switched on when CallKit tells
        // us its session went active.
        let audioSession = RTCAudioSession.sharedInstance()
        audioSession.useManualAudio = true
        audioSession.isAudioEnabled = false

        // `useManualAudio` means RTCAudioSession tracks activation itself.
        // Without being told CallKit activated the session its `isActive`
        // stays false, the audio unit never starts, and the call is silent
        // in both directions.
        NotificationCenter.default.addObserver(
            forName: .callAudioSessionActivated, object: nil, queue: .main
        ) { note in
            let rtc = RTCAudioSession.sharedInstance()
            if let session = note.object as? AVAudioSession {
                rtc.audioSessionDidActivate(session)
            }
            rtc.isAudioEnabled = true
        }

        NotificationCenter.default.addObserver(
            forName: .callAudioSessionDeactivated, object: nil, queue: .main
        ) { [weak self] note in
            // A deactivation belonging to a call that has already ended can
            // land after the next call has activated the session -- back to
            // back calls do this. Acting on it then turns the live call's
            // audio off, in both directions.
            let live = MainActor.assumeIsolated { self?.isConnected ?? false }
            guard !live else { return }
            let rtc = RTCAudioSession.sharedInstance()
            rtc.isAudioEnabled = false
            if let session = note.object as? AVAudioSession {
                rtc.audioSessionDidDeactivate(session)
            }
        }
    }

    // MARK: - Off-main execution
    //
    // libmediasoupclient's create/produce/consume calls are synchronous and
    // block the calling thread until their delegate callback comes back --
    // and those callbacks hop to the main actor to send a signalling
    // request. Calling them ON the main actor therefore deadlocks: the main
    // thread waits for a callback that is queued behind itself. The whole
    // call screen freezes, buttons included, which is exactly what that
    // looks like from the outside.
    private nonisolated func offMain<T>(_ work: @escaping () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do { continuation.resume(returning: try work()) }
                catch { continuation.resume(throwing: error) }
            }
        }
    }

    // MARK: - Connect

    func connect(callId: String, video: Bool) async {
        await join(roomId: "call-\(callId)", role: "host", video: video, publish: true)
    }

    func connectToMeeting(meetingId: String, video: Bool = true) async {
        await join(roomId: "meet-\(meetingId)", role: "host", video: video, publish: true)
    }

    /// A livestream room is the stream id with no prefix, and the server
    /// only lets the stream's owner join as "host" or publish anything --
    /// joining a stream the way a meeting is joined was rejected outright,
    /// so no stream ever came up on the phone.
    func connectToLivestream(streamId: String, asHost: Bool) async {
        await join(roomId: streamId, role: asHost ? "host" : "viewer",
                   video: asHost, publish: asHost)
    }

    private func join(roomId: String, role: String, video: Bool, publish: Bool) async {
        guard webSocket == nil else { return }
        lastJoin = (roomId, role, video, publish)
        lastError = nil

        // Checked before anything is opened: a publisher without access
        // otherwise joins the room and sits there mute and blank, which
        // reads as the other side's fault.
        if publish, let problem = MediaPermissions.message(video: video) {
            lastError = problem
            return
        }

        configureAudioSession(roomId: roomId, publish: publish)

        if !Self.clientInitialized {
            MediasoupClient.initialize()
            Self.clientInitialized = true
        }

        guard let url = URL(string: signalingURL) else { return }
        let task = URLSession(configuration: .default).webSocketTask(with: url)
        webSocket = task
        task.resume()
        listen()
        startKeepAlive()

        do {
            let token = await APIClient.shared.currentToken() ?? ""
            // Both parties publish in a call and in a meeting, unlike a
            // broadcast where only the host does.
            let joined = try await request("join", [
                "roomId": roomId,
                "role": role,
                "token": token,
            ])

            guard let capabilities = joined["rtpCapabilities"] else {
                throw SignalingError.badReply("join returned no rtpCapabilities")
            }

            let device = Device(pcFactory: Self.factory)
            let capabilitiesJSON = Self.jsonString(capabilities)
            try await offMain { try device.load(with: capabilitiesJSON) }
            self.device = device

            try await createSendTransport()
            try await createReceiveTransport()
            // A livestream viewer consumes only: the server rejects
            // `produce` from a non-host there, and that rejection used to
            // take the whole join down with it.
            if publish { try await publishLocalMedia(video: video) }

            isConnected = true

            // Anything already being published in the room before we
            // arrived. Only `newProducer` fires from here on, so without
            // this an existing participant stays silent and invisible.
            if let existing = joined["existingProducers"] as? [[String: Any]] {
                for producer in existing {
                    if let producerId = producer["producerId"] as? String,
                       let kind = producer["kind"] as? String {
                        await consume(producerId: producerId, kind: kind)
                    }
                }
            }
        } catch {
            print("WebRTC join failed: \(error)")
            teardown()
            lastError = error.localizedDescription
            handleConnectionLoss()
        }
    }

    /// Pings the signalling socket periodically.
    ///
    /// Nothing crosses this socket between call setup and hang-up, so any
    /// idle timeout in front of the server -- a proxy, a load balancer --
    /// closes it a few minutes in. The server closes that peer's mediasoup
    /// transports when the socket goes, so the call goes silent in both
    /// directions while the call screen still shows a running timer. That is
    /// the "audio just stops after a few minutes" case.
    private func startKeepAlive() {
        keepAlive?.cancel()
        keepAlive = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(20))
                guard !Task.isCancelled, let socket = self?.webSocket else { return }
                socket.sendPing { error in
                    if let error {
                        print("Signalling ping failed: \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    private func createSendTransport() async throws {
        guard let device else { throw SignalingError.notReady }
        let params = try await request("createTransport", [:])

        let handler = SendTransportHandler()
        handler.manager = self
        sendHandler = handler

        let id = try Self.string(params, "id")
        let ice = Self.jsonString(params["iceParameters"] ?? [:])
        let candidates = Self.jsonString(params["iceCandidates"] ?? [])
        let dtls = Self.jsonString(params["dtlsParameters"] ?? [:])

        let transport = try await offMain {
            try device.createSendTransport(
                id: id, iceParameters: ice, iceCandidates: candidates,
                dtlsParameters: dtls, sctpParameters: nil, appData: nil
            )
        }
        transport.delegate = handler
        sendTransport = transport
    }

    private func createReceiveTransport() async throws {
        guard let device else { throw SignalingError.notReady }
        let params = try await request("createTransport", [:])

        let handler = ReceiveTransportHandler()
        handler.manager = self
        receiveHandler = handler

        let id = try Self.string(params, "id")
        let ice = Self.jsonString(params["iceParameters"] ?? [:])
        let candidates = Self.jsonString(params["iceCandidates"] ?? [])
        let dtls = Self.jsonString(params["dtlsParameters"] ?? [:])

        let transport = try await offMain {
            try device.createReceiveTransport(
                id: id, iceParameters: ice, iceCandidates: candidates,
                dtlsParameters: dtls, appData: nil
            )
        }
        transport.delegate = handler
        receiveTransport = transport
    }

    /// Calls get their session from CallKit, which activates it and posts
    /// `.callAudioSessionActivated`. Meetings and livestreams never touch
    /// CallKit, so nothing ever flipped `isAudioEnabled` back on for them
    /// and they ran completely silent in both directions.
    private func configureAudioSession(roomId: String, publish: Bool) {
        guard !roomId.hasPrefix("call-") else {
            // CallKit already activated the session. If it did so before this
            // singleton existed the activation notification went nowhere, so
            // the latched session is picked up here instead. Both calls are
            // idempotent, so doing it twice is harmless.
            if let session = CallAudioSession.active {
                RTCAudioSession.sharedInstance().audioSessionDidActivate(session)
                RTCAudioSession.sharedInstance().isAudioEnabled = true
            }
            return
        }

        let session = AVAudioSession.sharedInstance()
        if publish {
            try? session.setCategory(.playAndRecord, mode: .voiceChat,
                                     options: [.allowBluetoothHFP, .defaultToSpeaker])
        } else {
            // A viewer records nothing, and `.playAndRecord` would light up
            // the mic indicator for someone who is only watching.
            try? session.setCategory(.playback, mode: .moviePlayback)
        }
        try? session.setActive(true)
        RTCAudioSession.sharedInstance().isAudioEnabled = true
    }

    // MARK: - Local media

    private func publishLocalMedia(video: Bool) async throws {
        guard let sendTransport else { throw SignalingError.notReady }

        let audioSource = Self.factory.audioSource(with: nil)
        let audioTrack = Self.factory.audioTrack(with: audioSource, trackId: "ngs-audio")
        audioProducer = try await offMain {
            try sendTransport.createProducer(
                for: audioTrack, encodings: nil, codecOptions: nil, codec: nil, appData: nil
            )
        }

        guard video else {
            setMuted(isMuted)
            return
        }

        let videoSource = Self.factory.videoSource()
        let capturer = RTCCameraVideoCapturer(delegate: videoSource)
        videoCapturer = capturer
        startCapture(capturer)

        let videoTrack = Self.factory.videoTrack(with: videoSource, trackId: "ngs-video")
        localVideoTrack = videoTrack
        videoProducer = try await offMain {
            try sendTransport.createProducer(
                for: videoTrack, encodings: nil, codecOptions: nil, codec: nil, appData: nil
            )
        }
        // A reconnect builds fresh producers, which start live regardless of
        // what the user had chosen. Without this a muted call comes back
        // unmuted, and a camera turned off comes back on.
        setMuted(isMuted)
        setCameraEnabled(isCameraEnabled)
    }

    private func startCapture(_ capturer: RTCCameraVideoCapturer) {
        let wanted: AVCaptureDevice.Position = isUsingFrontCamera ? .front : .back
        guard let camera = RTCCameraVideoCapturer.captureDevices()
            .first(where: { $0.position == wanted })
            ?? RTCCameraVideoCapturer.captureDevices().first else { return }

        let formats = RTCCameraVideoCapturer.supportedFormats(for: camera)
        // 640x480-ish is plenty for a call and costs far less battery and
        // uplink than the highest format the camera advertises.
        let format = formats.min(by: { lhs, rhs in
            let l = CMVideoFormatDescriptionGetDimensions(lhs.formatDescription)
            let r = CMVideoFormatDescriptionGetDimensions(rhs.formatDescription)
            return abs(Int(l.width) - 640) < abs(Int(r.width) - 640)
        }) ?? formats.first

        guard let format else { return }
        let fps = format.videoSupportedFrameRateRanges
            .map { Int($0.maxFrameRate) }.max() ?? 30

        capturer.startCapture(with: camera, format: format, fps: min(fps, 30))
    }

    // MARK: - Consuming

    fileprivate func consume(producerId: String, kind: String) async {
        guard let device, let receiveTransport else { return }
        do {
            let capabilities = try device.rtpCapabilities()
            let reply = try await request("consume", [
                "transportId": receiveTransport.id,
                "producerId": producerId,
                "rtpCapabilities": Self.jsonObject(capabilities) ?? [:],
            ])

            let consumerId = try Self.string(reply, "id")
            let rtpParameters = Self.jsonString(reply["rtpParameters"] ?? [:])
            let mediaKind: MediaKind = kind == "audio" ? .audio : .video
            let consumer = try await offMain {
                try receiveTransport.consume(
                    consumerId: consumerId,
                    producerId: producerId,
                    kind: mediaKind,
                    rtpParameters: rtpParameters,
                    appData: nil
                )
            }
            consumers[consumerId] = consumer

            // The server creates every consumer paused so the client can
            // attach its renderer without racing the first frames.
            _ = try await request("resumeConsumer", ["consumerId": consumerId])
            consumer.resume()

            if let track = consumer.track as? RTCVideoTrack {
                remoteVideoTrack = track
            }
        } catch {
            print("Consume failed for producer \(producerId): \(error)")
        }
    }

    // MARK: - Controls

    func setMuted(_ muted: Bool) {
        isMuted = muted
        guard let audioProducer else { return }
        muted ? audioProducer.pause() : audioProducer.resume()
    }

    func setCameraEnabled(_ enabled: Bool) {
        isCameraEnabled = enabled
        guard let videoProducer else { return }
        enabled ? videoProducer.resume() : videoProducer.pause()
        localVideoTrack?.isEnabled = enabled
    }

    /// Front/back camera. The same capturer is restarted on the other
    /// device, so the track -- and with it the producer the far end is
    /// already consuming -- stays exactly where it is.
    func switchCamera() {
        guard let capturer = videoCapturer else { return }
        isUsingFrontCamera.toggle()
        capturer.stopCapture { [weak self] in
            Task { @MainActor in self?.startCapture(capturer) }
        }
    }

    func disconnect() {
        reconnect?.cancel()
        reconnect = nil
        isReconnecting = false
        lastJoin = nil
        isMuted = false
        isCameraEnabled = true
        isUsingFrontCamera = true
        teardown()
    }

    /// Re-joins the same room for up to `reconnectWindow` seconds, and only
    /// ends the call if the window runs out. Everything the old connection
    /// held is dead by now, so each attempt starts from a clean teardown.
    private func handleConnectionLoss() {
        guard reconnect == nil, let params = lastJoin else { return }
        isReconnecting = true
        reconnect = Task { @MainActor [weak self] in
            let deadline = Date().addingTimeInterval(self?.reconnectWindow ?? 15)
            while !Task.isCancelled, Date() < deadline {
                self?.teardown()
                await self?.join(roomId: params.roomId, role: params.role,
                                 video: params.video, publish: params.publish)
                guard let self, !Task.isCancelled else { return }
                if isConnected {
                    isReconnecting = false
                    lastError = nil
                    reconnect = nil
                    return
                }
                try? await Task.sleep(for: .seconds(2))
            }
            guard let self, !Task.isCancelled else { return }
            reconnect = nil
            isReconnecting = false
            disconnect()
            lastError = "The call connection was lost."
            CallService.shared.endCall()
        }
    }

    private func teardown() {
        keepAlive?.cancel()
        keepAlive = nil

        videoCapturer?.stopCapture()
        videoCapturer = nil

        consumers.values.forEach { $0.close() }
        consumers.removeAll()

        audioProducer?.close()
        videoProducer?.close()
        audioProducer = nil
        videoProducer = nil

        sendTransport?.close()
        receiveTransport?.close()
        sendTransport = nil
        receiveTransport = nil
        sendHandler = nil
        receiveHandler = nil
        device = nil

        remoteVideoTrack = nil
        localVideoTrack = nil

        RTCAudioSession.sharedInstance().isAudioEnabled = false

        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
        isConnected = false

        failAllPending(SignalingError.disconnected)
    }

    // MARK: - Signalling

    private var signalingURL: String {
        APIClient.baseURL.replacingOccurrences(of: "https://", with: "wss://")
                         .replacingOccurrences(of: "http://", with: "ws://") + "/ws/live"
    }

    @discardableResult
    fileprivate func request(_ method: String, _ data: [String: Any]) async throws -> [String: Any] {
        let reqId = UUID().uuidString
        let payload: [String: Any] = ["reqId": reqId, "method": method, "data": data]

        guard let body = try? JSONSerialization.data(withJSONObject: payload),
              let text = String(data: body, encoding: .utf8),
              let webSocket else {
            throw SignalingError.notReady
        }

        return try await withCheckedThrowingContinuation { continuation in
            pending[reqId] = continuation
            // A reply that never arrives has to fail eventually. Without
            // this the continuation hangs forever, and every caller of
            // `join` hangs with it -- which froze the whole call screen.
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(15))
                self?.resumePending(reqId, with: .failure(SignalingError.timedOut))
            }
            webSocket.send(.string(text)) { [weak self] error in
                guard let error else { return }
                Task { @MainActor in self?.resumePending(reqId, with: .failure(error)) }
            }
        }
    }

    private func resumePending(_ reqId: String, with result: Result<[String: Any], Error>) {
        guard let continuation = pending.removeValue(forKey: reqId) else { return }
        continuation.resume(with: result)
    }

    private func failAllPending(_ error: Error) {
        let waiting = pending
        pending.removeAll()
        waiting.values.forEach { $0.resume(throwing: error) }
    }

    private func listen() {
        webSocket?.receive { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                switch result {
                case .success(let message):
                    if case .string(let text) = message { self.handle(text) }
                    if self.webSocket != nil { self.listen() }
                case .failure(let error):
                    print("Signalling socket closed: \(error.localizedDescription)")
                    self.isConnected = false
                    // Otherwise every in-flight request hangs forever.
                    self.failAllPending(error)
                    // Losing this socket kills the media with it, but the
                    // cause is usually transient -- retry before giving the
                    // call up.
                    self.handleConnectionLoss()
                }
            }
        }
    }

    private func handle(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return }

        if let reqId = json["reqId"] as? String {
            if json["ok"] as? Bool == true {
                resumePending(reqId, with: .success(json["data"] as? [String: Any] ?? [:]))
            } else {
                let message = json["error"] as? String ?? "Signalling request failed."
                resumePending(reqId, with: .failure(SignalingError.server(message)))
            }
            return
        }

        // One-way notifications use `notification`, not `type`.
        guard let notification = json["notification"] as? String else { return }
        let payload = json["data"] as? [String: Any] ?? [:]

        switch notification {
        case "newProducer":
            if let producerId = payload["producerId"] as? String,
               let kind = payload["kind"] as? String {
                Task { await self.consume(producerId: producerId, kind: kind) }
            }
        case "peerClosed":
            remoteVideoTrack = nil
            // In a call there is only one other peer, so its media going
            // away is the call ending. A meeting or a stream loses one of
            // many peers and carries on.
            if lastJoin?.roomId.hasPrefix("call-") == true {
                CallService.shared.remoteHungUp()
            }
        default:
            break
        }
    }

    // MARK: - JSON helpers

    fileprivate static func jsonString(_ value: Any) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: value),
              let text = String(data: data, encoding: .utf8) else { return "{}" }
        return text
    }

    fileprivate static func jsonObject(_ text: String) -> Any? {
        guard let data = text.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data)
    }

    private static func string(_ dictionary: [String: Any], _ key: String) throws -> String {
        guard let value = dictionary[key] as? String else {
            throw SignalingError.badReply("missing \(key)")
        }
        return value
    }
}

enum SignalingError: LocalizedError {
    case notReady
    case disconnected
    case timedOut
    case server(String)
    case badReply(String)

    var errorDescription: String? {
        switch self {
        case .notReady:              return "The call isn't connected yet."
        case .disconnected:          return "The call disconnected."
        case .timedOut:              return "The call server didn't respond."
        case .server(let message):   return message
        case .badReply(let detail):  return "Unexpected signalling reply (\(detail))."
        }
    }
}

// MARK: - Transport delegates
//
// mediasoup calls these from its own threads, so they are deliberately not
// MainActor-isolated; each hops back before touching the manager.

private final class SendTransportHandler: NSObject, SendTransportDelegate {
    weak var manager: WebRTCManager?

    func onConnect(transport: any Transport, dtlsParameters: String) {
        let transportId = transport.id
        Task { @MainActor [weak self] in
            _ = try? await self?.manager?.request("connectTransport", [
                "transportId": transportId,
                "dtlsParameters": WebRTCManager.jsonObject(dtlsParameters) ?? [:],
            ])
        }
    }

    func onConnectionStateChange(transport: any Transport, connectionState: TransportConnectionState) {}

    func onProduce(transport: any Transport, kind: MediaKind, rtpParameters: String,
                   appData: String, callback: @escaping (String?) -> Void) {
        let transportId = transport.id
        Task { @MainActor [weak self] in
            guard let manager = self?.manager else { return callback(nil) }
            do {
                let reply = try await manager.request("produce", [
                    "transportId": transportId,
                    "kind": kind == .audio ? "audio" : "video",
                    "rtpParameters": WebRTCManager.jsonObject(rtpParameters) ?? [:],
                ])
                // The server's producer id is what mediasoup-client needs
                // back; handing it nil leaves the producer permanently
                // half-created and the track never reaches anyone.
                callback(reply["id"] as? String)
            } catch {
                print("Produce failed: \(error)")
                callback(nil)
            }
        }
    }

    func onProduceData(transport: any Transport, sctpParameters: String, label: String,
                       protocol dataProtocol: String, appData: String,
                       callback: @escaping (String?) -> Void) {
        callback(nil) // No data channels in calls.
    }
}

private final class ReceiveTransportHandler: NSObject, ReceiveTransportDelegate {
    weak var manager: WebRTCManager?

    func onConnect(transport: any Transport, dtlsParameters: String) {
        let transportId = transport.id
        Task { @MainActor [weak self] in
            _ = try? await self?.manager?.request("connectTransport", [
                "transportId": transportId,
                "dtlsParameters": WebRTCManager.jsonObject(dtlsParameters) ?? [:],
            ])
        }
    }

    func onConnectionStateChange(transport: any Transport, connectionState: TransportConnectionState) {}
}
