import SwiftUI
import AVKit
import WebKit

/// Plays a video URL with whichever engine can actually decode it.
///
/// The web app records with MediaRecorder, which produces WebM (VP8/VP9).
/// AVFoundation has never supported WebM, so `AVPlayer` shows its
/// crossed-out-play glyph for every video the website uploaded. WebKit does
/// support WebM, so those go through a `WKWebView` instead.
///
/// The real fix is transcoding to H.264/MP4 on upload — one ffmpeg pass at
/// the server, after which this whole file can be deleted. Until that
/// exists, this is what makes existing videos watchable on iOS at all.
struct VideoSurface: View {
    let url: URL?
    var loop = false
    var autoplay = true
    /// A player is only built while this is true. Off-screen cards therefore
    /// hold no `AVPlayer` and no `WKWebView` at all, which is what stops a
    /// scrolled-past video from carrying on playing -- and stops a long feed
    /// from standing up a dozen players at once.
    var isActive = true
    /// Reported roughly once a second while playing, for the WebKit path.
    var onProgress: ((Double) -> Void)?

    private var needsWebKit: Bool {
        guard let url else { return false }
        return ["webm", "mkv", "ogv"].contains(url.pathExtension.lowercased())
    }

    var body: some View {
        ZStack {
            Color.black
            if let url, isActive {
                if needsWebKit {
                    WebVideoView(url: url, loop: loop, autoplay: autoplay, onProgress: onProgress)
                } else {
                    AVVideoView(url: url, loop: loop, autoplay: autoplay)
                }
            } else if url != nil {
                Image(systemName: "play.circle")
                    .font(.system(size: 44))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
    }
}

/// True while the tab this view lives in is the selected one. `TabView` keeps
/// every tab mounted, so a card in an unselected tab keeps whatever geometry
/// it had -- and a video in it kept playing, audible, from another tab.
private struct TabIsActiveKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    var isTabActive: Bool {
        get { self[TabIsActiveKey.self] }
        set { self[TabIsActiveKey.self] = newValue }
    }
}

/// Runs its content with a flag saying whether the view is substantially on
/// screen, so only what a person is actually looking at does expensive work.
///
/// iOS 18 has `onScrollVisibilityChange` for exactly this; the deployment
/// target here is 17, so visibility is measured against the screen by hand.
struct PlaysWhenVisible<Content: View>: View {
    @ViewBuilder let content: (Bool) -> Content

    @State private var isVisible = false
    @Environment(\.isTabActive) private var isTabActive
    @Environment(\.scenePhase) private var scenePhase

    /// Geometry alone is not enough: an unselected tab and a backgrounded app
    /// both leave the frame exactly where it was.
    private var shouldPlay: Bool {
        isVisible && isTabActive && scenePhase == .active
    }

    var body: some View {
        content(shouldPlay)
            .background(
                GeometryReader { geometry in
                    Color.clear.preference(key: VisibleFractionKey.self,
                                           value: visibleFraction(of: geometry.frame(in: .global)))
                }
            )
            .onPreferenceChange(VisibleFractionKey.self) { fraction in
                // Hysteresis, so a video doesn't stop and start repeatedly
                // while someone holds a card near the threshold.
                let next = isVisible ? fraction > 0.25 : fraction > 0.6
                if next != isVisible { isVisible = next }
            }
    }

    private func visibleFraction(of frame: CGRect) -> CGFloat {
        guard frame.height > 0 else { return 0 }
        let screen = UIScreen.main.bounds
        let overlap = frame.intersection(screen).height
        return max(0, overlap / frame.height)
    }
}

private struct VisibleFractionKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

enum MediaAudio {
    /// Without this, media runs on the default `soloAmbient` category, which
    /// the Ring/Silent switch mutes outright -- a video that plays with no
    /// sound reads as broken rather than as a deliberate setting.
    ///
    /// A call owns the session while it lasts (`.playAndRecord`/`.voiceChat`),
    /// and stealing it mid-call would break the call's routing, so an active
    /// call is left alone.
    static func activateForPlayback() {
        let session = AVAudioSession.sharedInstance()
        guard session.category != .playAndRecord else { return }
        try? session.setCategory(.playback, mode: .moviePlayback)
        try? session.setActive(true)
    }
}

/// Escaping for untrusted text placed inside an HTML attribute.
enum HTMLAttribute {
    /// `&` has to go first, or the ampersands introduced by the later
    /// replacements get escaped a second time.
    static func escaped(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    #if DEBUG
    /// Runs once, the first time a web-backed video builds its document.
    /// This is the check that fails loudly if the escaping above is ever
    /// weakened -- the project has no test target to put it in.
    static let selfCheckPassed: Bool = {
        assert(escaped("a&b") == "a&amp;b")
        assert(escaped("a\"b") == "a&quot;b")
        assert(escaped("\"><script>x</script>") == "&quot;&gt;&lt;script&gt;x&lt;/script&gt;")
        assert(escaped("' onerror='alert(1)") == "&#39; onerror=&#39;alert(1)")
        assert(escaped("https://h/a.webm") == "https://h/a.webm", "ordinary URLs must pass through")
        return true
    }()
    #endif
}

/// The ordinary path: anything AVFoundation understands.
struct AVVideoView: View {
    let url: URL
    var loop = false
    var autoplay = true

    @State private var player: AVPlayer?
    @State private var endObserver: NSObjectProtocol?

    var body: some View {
        ZStack {
            Color.black
            if let player {
                VideoPlayer(player: player)
            }
        }
        .onAppear(perform: start)
        .onDisappear(perform: stop)
    }

    private func start() {
        MediaAudio.activateForPlayback()
        let item = AVPlayerItem(url: url)
        let newPlayer = AVPlayer(playerItem: item)
        if loop {
            newPlayer.actionAtItemEnd = .none
            endObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main
            ) { _ in
                newPlayer.seek(to: .zero)
                newPlayer.play()
            }
        }
        player = newPlayer
        if autoplay { newPlayer.play() }
    }

    private func stop() {
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        endObserver = nil
        // Several players left running overlap their audio, which is the
        // bug this guarantees against.
        player?.pause()
        player = nil
    }
}

/// WebKit fallback. Wraps the URL in a bare `<video>` document rather than
/// navigating straight to the file, so playback can be inline, muted-free,
/// looping, and — when even WebKit can't decode it — replaced with a message
/// that says so instead of a silent black rectangle.
struct WebVideoView: UIViewRepresentable {
    let url: URL
    var loop: Bool
    var autoplay: Bool
    var onProgress: ((Double) -> Void)?

    func makeCoordinator() -> Coordinator { Coordinator(onProgress: onProgress) }

    func makeUIView(context: Context) -> WKWebView {
        MediaAudio.activateForPlayback()
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        // Without this, autoplay is refused and every reel needs a tap.
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.userContentController.add(context.coordinator, name: "progress")

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.isScrollEnabled = false
        // Otherwise the web view swallows the vertical swipe that pages
        // between reels.
        webView.scrollView.panGestureRecognizer.isEnabled = false
        // Without this the scroll view adds a safe-area inset of its own and
        // the video sits pushed down and to the side of its container --
        // very visible inside the rotated reels pager.
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        // A syntactically valid origin that can never resolve to anything
        // real: the document stays same-origin with nothing, so an injection
        // gains no access to the API, while remote media still loads. A nil
        // baseURL would be stricter still, but WKWebView is unreliable about
        // fetching remote subresources from a null origin.
        webView.loadHTMLString(html, baseURL: URL(string: "https://video.invalid/"))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.onProgress = onProgress
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        // A web view that keeps playing after it's off screen keeps its
        // audio too.
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "progress")
        webView.loadHTMLString("", baseURL: nil)
    }

    /// The URL is built from a server-supplied filename, so it is untrusted
    /// input being placed inside an HTML attribute. Escaping it is what stops
    /// a filename containing a quote from closing the attribute and injecting
    /// markup; the scheme check stops `javascript:` and friends from ever
    /// reaching the `src` at all.
    private var safeSource: String? {
        guard let scheme = url.scheme?.lowercased(),
              scheme == "https" || scheme == "http" else { return nil }
        return HTMLAttribute.escaped(url.absoluteString)
    }

    private var html: String {
        #if DEBUG
        _ = HTMLAttribute.selfCheckPassed
        #endif
        guard let safeSource else {
            return "<html><body style=\"margin:0;background:#000\"></body></html>"
        }
        return """
        <!doctype html><html><head>
        <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
        <style>
          /* Pinned to the viewport rather than laid out in flow: the reels
             pager rotates its container, and anything relying on normal
             document flow ends up offset inside it. */
          html,body{margin:0;padding:0;width:100%;height:100%;background:#000;overflow:hidden}
          video,#fallback{position:fixed;top:0;left:0;right:0;bottom:0;width:100%;height:100%}
          video{object-fit:contain;background:#000}
          #fallback{display:none;color:#94a3b8;font:14px -apple-system;
                    align-items:center;justify-content:center;
                    text-align:center;padding:24px;box-sizing:border-box}
        </style></head><body>
        <video id="v" src="\(safeSource)" playsinline \(autoplay ? "autoplay" : "") \(loop ? "loop" : "")></video>
        <div id="fallback">This video was recorded in a format iOS can&rsquo;t play (WebM/VP9).
        It plays on the website.</div>
        <script>
          const v = document.getElementById('v'), f = document.getElementById('fallback');
          function post(t){ try { webkit.messageHandlers.progress.postMessage(t); } catch (e) {} }
          v.addEventListener('timeupdate', () => post(v.currentTime));

          function giveUp(){ clearTimeout(timer); v.style.display='none'; f.style.display='flex'; }
          v.addEventListener('error', giveUp);

          // A codec WebKit can't decode does not reliably raise `error` --
          // it can simply sit there showing nothing, which is the black
          // rectangle this replaces. Anything that has produced no decoded
          // frame by now is treated as unplayable, because to the person
          // holding the phone that is exactly what it is.
          let timer = setTimeout(() => { if (v.readyState < 2) giveUp(); }, 5000);
          v.addEventListener('loadeddata', () => clearTimeout(timer));
        </script></body></html>
        """
    }

    final class Coordinator: NSObject, WKScriptMessageHandler {
        var onProgress: ((Double) -> Void)?

        init(onProgress: ((Double) -> Void)?) { self.onProgress = onProgress }

        func userContentController(_ controller: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            guard let seconds = message.body as? Double else { return }
            onProgress?(seconds)
        }
    }
}
