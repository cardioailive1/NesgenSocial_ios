import Foundation

/// The meeting you are currently in, held above the view tree.
///
/// A meeting has to outlive the screen that shows it: minimising it keeps the
/// media running while the rest of the app is used, exactly as `CallService`
/// does for calls. The room is presented from `RootView` for the same reason
/// -- navigating away from the Meet tab must not end the meeting.
@MainActor
final class MeetSession: ObservableObject {
    static let shared = MeetSession()

    @Published var activeMeeting: Meeting?
    @Published var isMinimized = false

    private init() {}

    func open(_ meeting: Meeting) {
        activeMeeting = meeting
        isMinimized = false
    }

    /// Called once the room has actually left the meeting server-side.
    func close() {
        activeMeeting = nil
        isMinimized = false
    }
}
