import Foundation
import CallKit
import AVFoundation
import PushKit

/// Native call handling via CallKit.
///
/// This is the piece a web app fundamentally cannot do: an incoming call
/// takes over the lock screen and rings like a phone call, even from a
/// terminated app. It requires VoIP push (PushKit), which Apple restricts
/// to apps that genuinely place calls -- fine here, but note that iOS
/// *requires* every VoIP push to report a call to CallKit. Receiving one
/// and not reporting it terminates the app, so there's no "silently check
/// for calls" path.
@MainActor
final class CallService: NSObject, ObservableObject {
    static let shared = CallService()

    @Published var activeCall: Call?
    @Published var isCallActive = false

    private let provider: CXProvider
    private let callController = CXCallController()
    private var pushRegistry: PKPushRegistry?
    private var currentCallUUID: UUID?

    private override init() {
        let configuration = CXProviderConfiguration()
        configuration.supportsVideo = true
        configuration.maximumCallsPerCallGroup = 1
        configuration.maximumCallGroups = 1
        configuration.supportedHandleTypes = [.generic]
        configuration.iconTemplateImageData = UIImage(named: "CallKitIcon")?.pngData()

        provider = CXProvider(configuration: configuration)
        super.init()
        provider.setDelegate(self, queue: nil)
    }

    func registerForVoIPPushes() {
        let registry = PKPushRegistry(queue: .main)
        registry.delegate = self
        registry.desiredPushTypes = [.voIP]
        pushRegistry = registry
    }

    /// Presents an incoming call on the system UI.
    func reportIncomingCall(callId: String, callerName: String, hasVideo: Bool,
                            completion: (() -> Void)? = nil) {
        let uuid = UUID()
        currentCallUUID = uuid

        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .generic, value: callerName)
        update.hasVideo = hasVideo
        update.localizedCallerName = callerName
        update.supportsHolding = false
        update.supportsGrouping = false
        update.supportsUngrouping = false

        provider.reportNewIncomingCall(with: uuid, update: update) { [weak self] error in
            if let error {
                print("CallKit reportNewIncomingCall failed: \(error.localizedDescription)")
            } else {
                Task { @MainActor in
                    await self?.loadCall(callId)
                }
            }
            completion?()
        }
    }

    func startOutgoingCall(to user: User, video: Bool) async throws -> Call {
        let response = try await APIClient.shared.post(
            "/api/messages/calls",
            body: ["username": user.username, "kind": video ? "VIDEO" : "AUDIO"],
            as: CallResponse.self
        )

        let uuid = UUID()
        currentCallUUID = uuid
        let handle = CXHandle(type: .generic, value: user.displayName)
        let action = CXStartCallAction(call: uuid, handle: handle)
        action.isVideo = video

        try await callController.request(CXTransaction(action: action))
        activeCall = response.call
        isCallActive = true
        return response.call
    }

    func endCall() {
        guard let uuid = currentCallUUID else { return }
        let action = CXEndCallAction(call: uuid)
        callController.request(CXTransaction(action: action)) { error in
            if let error { print("End call failed: \(error.localizedDescription)") }
        }
        if let callId = activeCall?.id {
            Task {
                _ = try? await APIClient.shared.patch(
                    "/api/messages/calls/\(callId)",
                    body: ["status": "ENDED"],
                    as: CallResponse.self
                )
            }
        }
        activeCall = nil
        isCallActive = false
        currentCallUUID = nil
    }

    private func loadCall(_ callId: String) async {
        activeCall = try? await APIClient.shared
            .get("/api/messages/calls/\(callId)/details", as: CallResponse.self).call
    }

    /// The audio session must be configured for voice chat or the call
    /// routes to the wrong output and echoes badly.
    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .voiceChat,
                                 options: [.allowBluetooth, .defaultToSpeaker])
        try? session.setActive(true)
    }
}

// MARK: - CXProviderDelegate

extension CallService: CXProviderDelegate {
    nonisolated func providerDidReset(_ provider: CXProvider) {
        Task { @MainActor in
            activeCall = nil
            isCallActive = false
        }
    }

    nonisolated func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        Task { @MainActor in
            configureAudioSession()
            isCallActive = true
            if let callId = activeCall?.id {
                _ = try? await APIClient.shared.patch(
                    "/api/messages/calls/\(callId)",
                    body: ["status": "ACTIVE"],
                    as: CallResponse.self
                )
            }
            action.fulfill()
        }
    }

    nonisolated func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        Task { @MainActor in
            if let callId = activeCall?.id {
                _ = try? await APIClient.shared.patch(
                    "/api/messages/calls/\(callId)",
                    body: ["status": "ENDED"],
                    as: CallResponse.self
                )
            }
            activeCall = nil
            isCallActive = false
            action.fulfill()
        }
    }

    nonisolated func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        Task { @MainActor in
            configureAudioSession()
            action.fulfill()
        }
    }

    nonisolated func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        // WebRTC starts sending audio once the session is active.
        NotificationCenter.default.post(name: .callAudioSessionActivated, object: nil)
    }
}

// MARK: - PKPushRegistryDelegate

extension CallService: PKPushRegistryDelegate {
    nonisolated func pushRegistry(_ registry: PKPushRegistry,
                                  didUpdate credentials: PKPushCredentials,
                                  for type: PKPushType) {
        let token = credentials.token.map { String(format: "%02x", $0) }.joined()
        Task {
            _ = try? await APIClient.shared.post(
                "/api/push/voip-subscribe",
                body: ["voipToken": token, "platform": "ios"],
                as: EmptyResponse.self
            )
        }
    }

    nonisolated func pushRegistry(_ registry: PKPushRegistry,
                                  didReceiveIncomingPushWith payload: PKPushPayload,
                                  for type: PKPushType) async {
        // iOS terminates the app if a VoIP push doesn't result in a
        // reported call, so this always reports something -- even with a
        // malformed payload, where "Incoming call" is better than a crash.
        let info = payload.dictionaryPayload
        let callId = info["callId"] as? String ?? ""
        let callerName = info["callerName"] as? String ?? "Incoming call"
        let hasVideo = (info["kind"] as? String) == "VIDEO"

        await MainActor.run {
            CallService.shared.reportIncomingCall(callId: callId,
                                                  callerName: callerName,
                                                  hasVideo: hasVideo)
        }
    }
}

extension Notification.Name {
    static let callAudioSessionActivated = Notification.Name("callAudioSessionActivated")
}
