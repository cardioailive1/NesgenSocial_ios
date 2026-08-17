import Foundation
import CallKit
import AVFoundation
import PushKit
import UIKit

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

    /// The call the in-app call screen is showing. Set only once a call is
    /// genuinely in progress -- while a call is merely ringing, CallKit owns
    /// the screen and presenting our own UI on top of it is wrong.
    @Published var activeCall: Call?
    @Published var isCallActive = false

    /// Loaded while the CallKit ringer is up, so answering can present
    /// immediately instead of waiting on a network round trip.
    private var pendingCall: Call?
    private var pendingCallId: String?
    /// Stops the poll from ringing the same call over and over while the
    /// server still reports it RINGING.
    private var lastReportedCallId: String?

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
        pendingCallId = callId
        pendingCall = nil

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
        let call = try await CallsService.start(with: user.username, video: video)

        let uuid = UUID()
        currentCallUUID = uuid
        let handle = CXHandle(type: .generic, value: user.displayName)
        let action = CXStartCallAction(call: uuid, handle: handle)
        action.isVideo = video

        try await callController.request(CXTransaction(action: action))
        activeCall = call
        pendingCallId = call.id
        isCallActive = true
        return call
    }

    /// Only asks CallKit to end the call. Reporting ENDED to the server and
    /// tearing down local state both happen in the CXEndCallAction delegate,
    /// which is the one path every ending goes through -- including the
    /// system call UI and the lock screen, which never touch this method.
    func endCall() {
        guard let uuid = currentCallUUID else { return }
        let action = CXEndCallAction(call: uuid)
        callController.request(CXTransaction(action: action)) { error in
            if let error { print("End call failed: \(error.localizedDescription)") }
        }
    }

    /// Fallback ringer for when the app is already open.
    ///
    /// VoIP push is the only thing that can ring a terminated app, but it
    /// needs an APNs `.p8` key configured on the server. Until that is in
    /// place -- and afterwards, for pushes that simply don't arrive -- this
    /// poll is what surfaces an incoming call at all.
    func pollForIncomingCalls() async {
        while !Task.isCancelled {
            if activeCall == nil, currentCallUUID == nil {
                let incoming = try? await CallsService.incoming()
                if let call = incoming, call.id != lastReportedCallId {
                    lastReportedCallId = call.id
                    reportIncomingCall(callId: call.id,
                                       callerName: call.caller?.displayName ?? "Incoming call",
                                       hasVideo: call.kind == "VIDEO")
                    // After reporting, which resets it: the poll already has
                    // the full call, so answering needs no extra fetch.
                    pendingCall = call
                }
            }
            try? await Task.sleep(for: .seconds(3))
        }
    }

    private func loadCall(_ callId: String) async {
        pendingCall = try? await CallsService.details(callId)
    }

    /// The audio session must be configured for voice chat or the call
    /// routes to the wrong output and echoes badly.
    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .voiceChat,
                                 options: [.allowBluetoothHFP, .defaultToSpeaker])
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
            // The VoIP push only carries an id, so if the details request
            // hasn't landed yet, wait for it rather than presenting nothing.
            if pendingCall == nil, let callId = pendingCallId {
                await loadCall(callId)
            }
            activeCall = pendingCall
            isCallActive = true
            if let callId = activeCall?.id {
                try? await CallsService.setStatus("ACTIVE", callId: callId)
            }
            action.fulfill()
        }
    }

    nonisolated func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        Task { @MainActor in
            // Declining from the CallKit ringer also lands here, and at that
            // point the call was never answered, so `activeCall` is nil.
            // Reporting only on `activeCall` left those calls stuck RINGING
            // on the server until they aged out.
            let wasAnswered = activeCall != nil
            if let callId = activeCall?.id ?? pendingCallId {
                try? await CallsService.setStatus(wasAnswered ? "ENDED" : "DECLINED",
                                                  callId: callId)
            }
            activeCall = nil
            pendingCall = nil
            pendingCallId = nil
            isCallActive = false
            currentCallUUID = nil
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
        // Environment and bundle id matter as much here as they do for the
        // normal APNs token, which is why both go through the same service.
        Task { try? await PushSubscriptionService.subscribeVoIP(token: token) }
    }

    // Must be the completion-handler form. The `async` variant is not part
    // of PKPushRegistryDelegate, so it is never called -- and a VoIP push
    // that goes unanswered terminates the app.
    nonisolated func pushRegistry(_ registry: PKPushRegistry,
                                  didReceiveIncomingPushWith payload: PKPushPayload,
                                  for type: PKPushType,
                                  completion: @escaping () -> Void) {
        // iOS terminates the app if a VoIP push doesn't result in a
        // reported call, so this always reports something -- even with a
        // malformed payload, where "Incoming call" is better than a crash.
        let info = payload.dictionaryPayload
        let callId = info["callId"] as? String ?? ""
        let callerName = info["callerName"] as? String ?? "Incoming call"
        let hasVideo = (info["kind"] as? String) == "VIDEO"

        Task { @MainActor in
            // completion() only after CallKit has been told about the call;
            // calling it earlier is what trips the termination check.
            CallService.shared.reportIncomingCall(callId: callId,
                                                  callerName: callerName,
                                                  hasVideo: hasVideo,
                                                  completion: completion)
        }
    }
}

extension Notification.Name {
    static let callAudioSessionActivated = Notification.Name("callAudioSessionActivated")
}
