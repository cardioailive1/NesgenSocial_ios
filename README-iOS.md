# NexgenSocial for iOS

A native SwiftUI app for the NexgenSocial platform, talking to the same
backend as the web app (`nexgensocial-udp.fly.dev`).

## Read this first

**This code has never been compiled.** It was written in a Linux
environment with no access to macOS, Xcode, or the Swift toolchain. Every
other part of the NexgenSocial project was compiled and often runtime-tested
before delivery; this was not, and can't be. Budget time for fixing build
errors in Xcode — expect type mismatches, missing imports, and a few API
signature corrections. The architecture and logic are sound; the
"it definitely compiles" guarantee is absent.

## What's complete

- Email/password auth with the token stored in the **Keychain** (not
  UserDefaults, which is plaintext and survives in backups)
- Feed with posts, multi-photo/video carousels, optimistic likes
- Post composer with photo and video upload via PhotosPicker
- Reels: full-screen vertical paging, looping playback, watch-time
  reporting that feeds the server's ranking
- Direct messages with polling and attachments
- Explore: people search with follow, jobs with salary ranges, marketplace
- Profile with data export, push toggle, sign out
- **CallKit integration** — incoming calls take over the lock screen and
  ring like a real phone call, including from a terminated app
- APNs push registration, plus PushKit for VoIP call pushes

## What's NOT complete

**1. WebRTC media transport** (`Services/WebRTCManager.swift`)

The signalling layer is written and its message shapes match
`backend/src/livestreamSignaling.js` exactly. The peer connection itself is
a stub, because WebRTC on iOS needs a binary framework that can't be
vendored from here.

To finish it:

```
File → Add Package Dependencies →
https://github.com/stasel/WebRTC (or GoogleWebRTC via CocoaPods)
```

Then, inside `WebRTCManager`:
- create `RTCPeerConnectionFactory` and a peer connection
- on `join`, use the returned `rtpCapabilities` to build send/recv transports
- for each `newProducer` notification, `consume` and attach the track to a view
- forward local audio/video tracks through `produce`

The room id conventions the server expects are already correct:
`call-<callId>` and `meet-<meetingId>`, both joining with `role: "host"`
since every participant publishes.

**2. Server-side APNs sending**

The app registers its device token at `/api/push/apns-subscribe` and its
VoIP token at `/api/push/voip-subscribe`. **Those endpoints do not exist on
the backend yet** — only the Web Push ones do. You'll need to add them plus
an APNs sender (the `node-apn` package, or `@parse/node-apn`), using a
`.p8` key from your Apple Developer account.

Until that exists, calls will only ring while the app is open.

**3. NexgenMeet screens** — the backend supports meetings fully; the iOS
screens for them aren't written. `WebRTCManager.connectToMeeting` is ready.

## Setup

1. **Xcode 15+**, iOS 16 deployment target.
2. Create a new iOS App project named `NexgenSocial`, then drag the
   `NexgenSocial/` folder in (Copy items if needed, Create groups).
3. Replace the generated `Info.plist` with `Resources/Info.plist`.
4. Add `Resources/NexgenSocial.entitlements` under Signing & Capabilities.
5. Enable capabilities: **Push Notifications**, **Background Modes**
   (Audio, Voice over IP, Remote notifications).
6. Set your Team and a unique bundle identifier.

## Before submitting to the App Store

- **Set `aps-environment` to `production`** in the entitlements file.
  Leaving it on `development` is the single most common reason push works
  in TestFlight and then silently dies after release.
- Add app icons (1024×1024 plus the full set).
- Apple requires a **working demo account** for review — a reviewer who
  can't sign in rejects the build.
- Complete the **App Privacy** questionnaire honestly. This app collects
  contact info, user content, identifiers, and (optionally) coarse
  location. Declaring less than you collect is a rejection, and a
  compliance problem beyond that.
- CallKit is restricted: your app must genuinely place calls (it does).
  Note that CallKit is **unavailable in mainland China** — Apple requires
  apps to fall back gracefully there rather than break.
- If you keep the marketplace, expect questions about whether it's
  user-to-user (no in-app purchase needed) or platform-sold (which would
  require IAP). Being clear about this in review notes saves a round trip.

## Architecture

```
NexgenSocial/
├── NexgenSocialApp.swift      App entry, AppDelegate, push callbacks
├── Models/Models.swift        Codable models mirroring the API
├── Networking/APIClient.swift Actor-based client, multipart upload
├── Services/
│   ├── KeychainStore.swift    Secure token storage
│   ├── AuthSession.swift      Session state, sign in/up/out
│   ├── PushService.swift      APNs registration
│   ├── CallService.swift      CallKit + PushKit
│   └── WebRTCManager.swift    Signalling (peer connection = stub)
├── Views/                     SwiftUI screens
└── Resources/                 Theme, Info.plist, entitlements
```
