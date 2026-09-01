import Foundation
import CallKit
import AVFoundation
import PushKit
import UIKit
import WebRTC

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

    /// Call screen pushed aside so the rest of the app is usable, with the
    /// call itself still running. Only the presentation changes -- media,
    /// CallKit and the server all carry on untouched.
    @Published var isMinimized = false

    /// What the call audio is actually coming out of.
    ///
    /// Published rather than tracked as a "speaker on" flag, because the
    /// route changes without the app asking: plugging in headphones or a
    /// Bluetooth headset connecting mid-call both reroute it, and a button
    /// that keeps claiming "Speaker" through that is simply lying.
    @Published private(set) var audioRoute = AudioRoute.receiver

    /// When the call was actually answered, so the in-call timer counts talk
    /// time rather than time since dialling. Nil while a call is still
    /// ringing, which is what the call screen shows "Ringing…" for.
    @Published var connectedAt: Date?

    /// Set the moment a call is over, while the call screen is still up. The
    /// screen otherwise vanished the instant the other side hung up, which
    /// reads as a crash rather than as the call ending.
    @Published var endedNotice: String?

    /// Ringback for the caller. The callee hears CallKit's ringer; without
    /// this the caller heard nothing at all until the call was answered.
    private let ringback = Ringback()

    /// True from the moment we place a call until the far end answers or the
    /// call ends. The ringback can only play once CallKit has activated the
    /// audio session, and that callback can land either side of the call
    /// being set up, so both paths check this rather than call order.
    private var wantsRingback = false

    /// Set when the final status is already on the server, so the end action
    /// doesn't patch a DECLINED back to an ENDED.
    private var suppressStatusReport = false

    /// Stops the starting route being re-imposed every time CallKit
    /// reactivates the session, which would undo the user's own choice.
    private var pickedStartingRoute = false

    /// Loaded while the CallKit ringer is up, so answering can present
    /// immediately instead of waiting on a network round trip.
    private var pendingCall: Call?
    private var pendingCallId: String?
    /// Stops the poll from ringing the same call over and over while the
    /// server still reports it RINGING.
    private var lastReportedCallId: String?
    /// Watches a call we placed. The caller gets no CallKit callback when the
    /// far end declines or never picks up, so the record itself is polled.
    private var callWatch: Task<Void, Never>?

    /// `nonisolated` because the PushKit delegate must report a call before
    /// it returns, and hopping to the main actor first is too late.
    nonisolated private let provider: CXProvider
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

        // Delivered on `.main`, so the hop is safe to assume.
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshAudioRoute() }
        }
    }

    func registerForVoIPPushes() {
        PushLog.write("registering PKPushRegistry for VoIP pushes")
        let registry = PKPushRegistry(queue: .main)
        registry.delegate = self
        registry.desiredPushTypes = [.voIP]
        pushRegistry = registry
    }

    /// Presents an incoming call on the system UI.
    ///
    /// Must stay synchronous up to `reportNewIncomingCall`: PushKit checks
    /// for a reported call as soon as its delegate method returns, and
    /// terminates the app if there isn't one. Any `await` before the report
    /// is an abort in `_terminateAppIfThereAreUnhandledVoIPPushes`.
    nonisolated func reportIncomingCall(callId: String, callerName: String, hasVideo: Bool,
                                        completion: (() -> Void)? = nil) {
        // Already ringing, from whichever of the two paths got here first.
        // Reporting it again stands up a second CallKit call for one
        // conversation, and with one call per group the answered one is torn
        // down about a second in -- which is exactly the second call in a
        // row failing while the first worked.
        if !callId.isEmpty, ReportedCall.id == callId {
            PushLog.write("duplicate report for \(callId) ignored")
            completion?()
            return
        }
        ReportedCall.id = callId.isEmpty ? nil : callId

        let uuid = UUID()

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
            }
            Task { @MainActor in
                guard let self else { completion?(); return }
                self.currentCallUUID = uuid
                self.pendingCallId = callId
                self.pendingCall = nil
                // Returned as soon as the call is reported. A cold launch
                // from a VoIP push runs on borrowed background time, and
                // holding PushKit's completion handler open for a network
                // round trip is what kills those calls a second or two in.
                // The details fetch carries on by itself; the answer action
                // waits for it if it has to.
                completion?()
                if error == nil { await self.loadCall(callId) }
            }
        }
    }

    func startOutgoingCall(to user: User, video: Bool) async throws -> Call {
        // Checked before the server call: placing it first would ring the
        // other side for a call this device can't carry audio on.
        if let problem = MediaPermissions.message(video: video) {
            throw CallPermissionError(message: problem)
        }

        let call = try await CallsService.start(with: user.username, video: video)

        let uuid = UUID()
        let handle = CXHandle(type: .generic, value: user.displayName)
        let action = CXStartCallAction(call: uuid, handle: handle)
        action.isVideo = video

        wantsRingback = true
        do {
            try await callController.request(CXTransaction(action: action))
        } catch {
            stopRingback()
            // `currentCallUUID` is set only once CallKit has accepted the
            // call: leaving it set after a refused transaction stops
            // `pollForIncomingCalls` from ever ringing again, which silently
            // kills incoming calls for the rest of the session.
            try? await CallsService.setStatus("ENDED", callId: call.id)
            throw error
        }

        currentCallUUID = uuid
        activeCall = call
        isMinimized = false
        pendingCallId = call.id
        isCallActive = true
        // Not connected yet -- the callee still has to answer.
        connectedAt = nil
        endedNotice = nil
        // If the session was already active this starts the tone now;
        // otherwise `didActivate` does, whichever lands second.
        if wantsRingback { ringback.start() }
        connectMedia()
        watchCall(callId: call.id)
        return call
    }

    /// Polls a call until it stops.
    ///
    ///
    /// Nothing else tells the caller what happened: a decline, a hang-up from
    /// the other side, or a call nobody picks up all leave the caller sitting
    /// on the call screen forever. This is also the only place that reports
    /// MISSED -- without it those records stay RINGING until they age out of
    /// the server's incoming window.
    private func watchCall(callId: String) {
        callWatch?.cancel()
        callWatch = Task { @MainActor [weak self] in
            let ringDeadline = Date().addingTimeInterval(60)
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                guard let self, !Task.isCancelled else { return }

                let call = try? await CallsService.details(callId)

                switch call?.status {
                case "ACTIVE":
                    self.stopRingback()
                    if self.connectedAt == nil {
                        self.connectedAt = Date()
                        // Moves CallKit out of "connecting", which is what
                        // makes it activate the audio session on the caller.
                        if let uuid = self.currentCallUUID {
                            self.provider.reportOutgoingCall(with: uuid, connectedAt: Date())
                        }
                    }
                    self.activeCall = call
                case "DECLINED", "ENDED", "MISSED":
                    // The server already holds the final status, so the end
                    // action must not patch over a DECLINED with an ENDED.
                    self.suppressStatusReport = true
                    self.pendingCallId = nil
                    self.endedNotice = call?.status == "DECLINED" ? "Call declined" : "Call ended"
                    self.endCall()
                    return
                default:
                    // Still RINGING, or the status request failed. The
                    // deadline is a no-answer timeout, so it only applies
                    // while the call is still ringing -- applying it to a
                    // connected call meant one failed poll past the first
                    // minute hung up on a live conversation as "No answer".
                    if self.connectedAt == nil, Date() >= ringDeadline {
                        try? await CallsService.setStatus("MISSED", callId: callId)
                        self.suppressStatusReport = true
                        self.pendingCallId = nil
                        self.endedNotice = "No answer"
                        self.endCall()
                        return
                    }
                }
            }
        }
    }

    /// The other side's media peer went away, which is a hang-up a good few
    /// seconds before the status poll would notice one.
    func remoteHungUp() {
        guard activeCall != nil, endedNotice == nil else { return }
        // Whoever left already wrote the final status; don't patch over it.
        suppressStatusReport = true
        endedNotice = "Call ended"
        endCall()
    }

    /// Only asks CallKit to end the call. Reporting ENDED to the server and
    /// tearing down local state both happen in the CXEndCallAction delegate,
    /// which is the one path every ending goes through -- including the
    /// system call UI and the lock screen, which never touch this method.
    func endCall() {
        guard let uuid = currentCallUUID else {
            // No CallKit call to end, so no end action will fire -- the call
            // screen would stay up forever waiting for one.
            showEndedThenDismiss()
            return
        }
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
            // `currentCallUUID` is only set once CallKit calls back, so a
            // pushed call is invisible to this guard for a moment --
            // `ReportedCall` is set synchronously and closes that window.
            if activeCall == nil, currentCallUUID == nil, ReportedCall.id == nil {
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

    /// Retried, and never clears what it already has.
    ///
    /// On a cold launch from a VoIP push this is the first request the
    /// process makes, often before the radio is back up. A single failure
    /// used to leave `pendingCall` nil, and answering then presented no call
    /// screen at all -- so nothing ever connected media and the call sat
    /// silent with CallKit showing it as up.
    private func loadCall(_ callId: String) async {
        for attempt in 0..<3 {
            if let call = try? await CallsService.details(callId) {
                pendingCall = call
                return
            }
            if attempt < 2 { try? await Task.sleep(for: .milliseconds(500)) }
        }
    }

    /// Brings up the media for whichever call is current. Safe to call more
    /// than once: `WebRTCManager` ignores a connect while it already has a
    /// session, which is what lets the call screen keep calling it too.
    func connectMedia() {
        guard let call = activeCall else { return }
        Task { @MainActor in
            await WebRTCManager.shared.connect(callId: call.id,
                                               video: call.kind == "VIDEO")
        }
    }

    private func stopRingback() {
        wantsRingback = false
        ringback.stop()
    }

    /// Routes through `RTCAudioSession` rather than `AVAudioSession`
    /// directly. WebRTC holds its own configuration lock over the session,
    /// and an override applied behind that lock gets reverted the next time
    /// WebRTC reconfigures -- the speaker button appeared to do nothing.
    func setSpeaker(_ on: Bool) {
        let rtc = RTCAudioSession.sharedInstance()
        rtc.lockForConfiguration()
        try? rtc.overrideOutputAudioPort(on ? .speaker : .none)
        rtc.unlockForConfiguration()
        refreshAudioRoute()
    }

    /// True when the audio can go somewhere other than the earpiece or the
    /// speaker. A plain speaker toggle can't express "or the AirPods", so
    /// the call screen swaps in the system route picker when this is set.
    var hasExternalAudioRoute: Bool {
        let session = AVAudioSession.sharedInstance()
        let external: Set<AVAudioSession.Port> = [
            .headphones, .headsetMic, .bluetoothA2DP, .bluetoothHFP,
            .bluetoothLE, .usbAudio, .carAudio, .airPlay,
        ]
        if session.currentRoute.outputs.contains(where: { external.contains($0.portType) }) {
            return true
        }
        return (session.availableInputs ?? [])
            .contains { external.contains($0.portType) }
    }

    private func refreshAudioRoute() {
        audioRoute = AudioRoute(AVAudioSession.sharedInstance().currentRoute.outputs.first)
    }

    /// Keeps the call screen up for a beat showing why it ended, then drops
    /// it. `activeCall` is what presents the screen, so clearing it is the
    /// dismissal.
    private func showEndedThenDismiss() {
        guard activeCall != nil else {
            endedNotice = nil
            return
        }
        if endedNotice == nil { endedNotice = "Call ended" }
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(1.5))
            self?.activeCall = nil
            self?.isMinimized = false
            self?.endedNotice = nil
        }
    }

    /// The audio session must be configured for voice chat or the call
    /// routes to the wrong output and echoes badly.
    private func configureAudioSession() {
        // Category only -- CallKit activates the session and posts
        // `didActivate`. Activating it here races CallKit and leaves
        // RTCAudioSession's own activation state wrong, which is silence.
        // No `.defaultToSpeaker`: it makes the speaker the route that
        // `overrideOutputAudioPort(.none)` returns to, which leaves the
        // earpiece unreachable from the call screen's output button. The
        // starting route is chosen explicitly in `didActivate` instead.
        try? AVAudioSession.sharedInstance()
            .setCategory(.playAndRecord, mode: .voiceChat,
                         options: [.allowBluetoothHFP])
    }
}

// MARK: - CXProviderDelegate

extension CallService: CXProviderDelegate {
    nonisolated func providerDidReset(_ provider: CXProvider) {
        Task { @MainActor in
            callWatch?.cancel()
            callWatch = nil
            stopRingback()
            WebRTCManager.shared.disconnect()
            ReportedCall.id = nil
            activeCall = nil
            isMinimized = false
            pickedStartingRoute = false
            endedNotice = nil
            isCallActive = false
            connectedAt = nil
            currentCallUUID = nil
        }
    }

    nonisolated func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        Task { @MainActor in
            configureAudioSession()
            // Fulfilled before anything else: CallKit gives an action a few
            // seconds and tears the call down if it hasn't been fulfilled by
            // then, and every line below is a network round trip. Answering
            // and having the call die a second later is exactly that timeout.
            action.fulfill()
            // The VoIP push only carries an id, so if the details request
            // hasn't landed yet, wait for it rather than presenting nothing.
            if pendingCall == nil, let callId = pendingCallId {
                await loadCall(callId)
            }
            activeCall = pendingCall
            // No record means no call screen, and the call screen is what
            // connects the media. Ending it says so; leaving it up is a call
            // that is silent for as long as the other side stays on it.
            guard activeCall != nil else {
                endedNotice = "Couldn't load the call."
                endCall()
                return
            }
            endedNotice = nil
            isMinimized = false
            isCallActive = true
            connectedAt = Date()
            // Connected here rather than from the call screen's `.task`.
            // Answering from the CallKit UI never brings the app to the
            // front, so that screen is not rendered and its task never runs
            // -- the call then has no media at all until the app is opened
            // by hand, which is every call after the first one in a
            // background session.
            connectMedia()
            if let callId = activeCall?.id {
                // The far end hanging up sends this side nothing at all, so
                // the answered call is polled too -- without it the callee
                // sat on a connected call screen after the caller had gone.
                watchCall(callId: callId)
                try? await CallsService.setStatus("ACTIVE", callId: callId)
            }
        }
    }

    nonisolated func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        Task { @MainActor in
            // Same reason as the answer action: fulfil before the status
            // round trip rather than after it.
            action.fulfill()
            // Declining from the CallKit ringer also lands here, and at that
            // point the call was never answered, so `activeCall` is nil.
            // Reporting only on `activeCall` left those calls stuck RINGING
            // on the server until they aged out.
            callWatch?.cancel()
            callWatch = nil
            stopRingback()
            let wasAnswered = activeCall != nil
            if !suppressStatusReport, let callId = activeCall?.id ?? pendingCallId {
                try? await CallsService.setStatus(wasAnswered ? "ENDED" : "DECLINED",
                                                  callId: callId)
            }
            suppressStatusReport = false
            pickedStartingRoute = false
            ReportedCall.id = nil
            pendingCall = nil
            pendingCallId = nil
            isCallActive = false
            connectedAt = nil
            currentCallUUID = nil
            // The call screen used to do this when it disappeared, which
            // made minimising it hang up. Ending the call is the only thing
            // that should drop the media.
            WebRTCManager.shared.disconnect()
            showEndedThenDismiss()
        }
    }

    nonisolated func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        Task { @MainActor in
            configureAudioSession()
            action.fulfill()
            // CallKit leaves an outgoing call in "dialling" until it is told
            // otherwise, and never activates the audio session for a call
            // that never starts connecting. Without this the caller's
            // `didActivate` never fires, so the caller neither sends nor
            // hears audio.
            provider.reportOutgoingCall(with: action.callUUID, startedConnectingAt: nil)
        }
    }

    nonisolated func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        // WebRTC starts sending audio once the session is active. The session
        // itself is passed along: RTCAudioSession needs the instance CallKit
        // activated, not just a flag.
        CallAudioSession.active = audioSession
        NotificationCenter.default.post(name: .callAudioSessionActivated,
                                        object: audioSession)
        Task { @MainActor in
            // An engine started before this point plays into a session that
            // isn't running yet, which is silence.
            if wantsRingback { ringback.start() }
            // A voice call starts at the earpiece the way a phone call does,
            // a video call on the speaker the way FaceTime does -- but never
            // over a headset the user has deliberately connected.
            if !pickedStartingRoute, !hasExternalAudioRoute {
                pickedStartingRoute = true
                setSpeaker((activeCall ?? pendingCall)?.kind == "VIDEO")
            }
            refreshAudioRoute()
        }
    }

    nonisolated func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        CallAudioSession.active = nil
        NotificationCenter.default.post(name: .callAudioSessionDeactivated,
                                        object: audioSession)
    }
}

// MARK: - PKPushRegistryDelegate

extension CallService: PKPushRegistryDelegate {
    nonisolated func pushRegistry(_ registry: PKPushRegistry,
                                  didUpdate credentials: PKPushCredentials,
                                  for type: PKPushType) {
        let token = credentials.token.map { String(format: "%02x", $0) }.joined()
        PushLog.write("VoIP push token received: \(token)")
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
        PushLog.write("VoIP push received: \(info)")
        let callId = info["callId"] as? String ?? ""
        let callerName = info["callerName"] as? String ?? "Incoming call"
        let hasVideo = (info["kind"] as? String) == "VIDEO"

        // Reported inline on PushKit's own queue -- `self` is the registry
        // delegate, so there is no need to reach for the singleton, and no
        // actor hop to delay the report past the termination check.
        reportIncomingCall(callId: callId,
                           callerName: callerName,
                           hasVideo: hasVideo,
                           completion: completion)
    }
}

extension Notification.Name {
    static let callAudioSessionActivated = Notification.Name("callAudioSessionActivated")
    static let callAudioSessionDeactivated = Notification.Name("callAudioSessionDeactivated")
}

/// The session CallKit has active, latched.
///
/// `didActivate` is a one-shot notification, and when a call is answered from
/// a VoIP push it fires before the call screen — and therefore before
/// `WebRTCManager.shared` — exists. Nobody is subscribed, the notification is
/// dropped, and the call runs silent both ways. Latching it lets the manager
/// read the state when it comes up instead of having to have been listening.
///
/// ponytail: two accesses, both effectively serialised by the call lifecycle
/// (CallKit's queue writes, the main actor reads on join). Wrap in a lock if
/// anything else ever touches it.
enum CallAudioSession {
    nonisolated(unsafe) static var active: AVAudioSession?
}

/// The call CallKit has been told about, set the moment it is reported.
///
/// Both the VoIP push and the incoming poll report calls, and the poll is
/// live in the background once a push has woken the app -- so the second
/// call of a session could be reported twice, once by each.
///
/// ponytail: written on PushKit's queue, read on the main actor, serialised
/// in practice by the call lifecycle. Same trade-off as `CallAudioSession`.
enum ReportedCall {
    nonisolated(unsafe) static var id: String?
}

struct CallPermissionError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

/// Caller-side ringback tone, synthesised rather than shipped as an asset:
/// it is two sine waves, and generating them is smaller than a sound file in
/// the repo. Plays through the call's audio session, so it follows the same
/// route as the call itself.
final class Ringback {
    private let engine = AVAudioEngine()
    private let node = AVAudioPlayerNode()

    func start() {
        guard !engine.isRunning else { return }
        let rate = 8000.0
        guard let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format,
                                            frameCapacity: AVAudioFrameCount(rate * 6))
        else { return }

        // US cadence: 440 Hz + 480 Hz for two seconds, four seconds of
        // silence, looped by the player node.
        buffer.frameLength = buffer.frameCapacity
        let samples = buffer.floatChannelData![0]
        for frame in 0..<Int(buffer.frameLength) {
            let t = Double(frame) / rate
            samples[frame] = t < 2
                ? Float((sin(2 * .pi * 440 * t) + sin(2 * .pi * 480 * t)) * 0.15)
                : 0
        }

        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        guard (try? engine.start()) != nil else {
            engine.detach(node)
            return
        }
        node.scheduleBuffer(buffer, at: nil, options: .loops)
        node.play()
    }

    func stop() {
        guard engine.isRunning else { return }
        node.stop()
        engine.stop()
        engine.detach(node)
    }
}


/// The current audio output, as something the call screen can render.
///
/// Carries its own label because a Bluetooth route's useful name is the
/// device's own ("Rishi's AirPods"), not the word "Bluetooth".
struct AudioRoute: Equatable {
    let icon: String
    let label: String
    let isSpeaker: Bool

    static let receiver = AudioRoute(icon: "iphone", label: "iPhone", isSpeaker: false)

    init(icon: String, label: String, isSpeaker: Bool) {
        self.icon = icon
        self.label = label
        self.isSpeaker = isSpeaker
    }

    init(_ port: AVAudioSessionPortDescription?) {
        guard let port else { self = .receiver; return }
        switch port.portType {
        case .builtInSpeaker:
            self = AudioRoute(icon: "speaker.wave.2.fill", label: "Speaker", isSpeaker: true)
        case .builtInReceiver:
            self = .receiver
        case .headphones, .headsetMic, .usbAudio:
            self = AudioRoute(icon: "headphones", label: "Headphones", isSpeaker: false)
        case .bluetoothA2DP, .bluetoothHFP, .bluetoothLE:
            self = AudioRoute(icon: "headphones", label: port.portName, isSpeaker: false)
        case .carAudio:
            self = AudioRoute(icon: "car.fill", label: port.portName, isSpeaker: false)
        case .airPlay:
            self = AudioRoute(icon: "airplayaudio", label: port.portName, isSpeaker: false)
        default:
            self = AudioRoute(icon: "speaker.wave.2.fill", label: port.portName, isSpeaker: false)
        }
    }
}
