import Foundation

/// Parsing and display of the ISO-8601 timestamps the API returns.
///
/// Every screen that shows a time needs the same handful of formats, and the
/// parsing has one real trap in it: the server sometimes includes fractional
/// seconds and sometimes doesn't, and an `ISO8601DateFormatter` configured for
/// one form returns nil for the other. Both are tried here, once, in a shared
/// place -- formatters are expensive to build, so they are created once and
/// reused.
enum ServerDate {

    private static let withFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let plain = ISO8601DateFormatter()

    private static let clock: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "hh:mm a"
        return formatter
    }()

    private static let weekday: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter
    }()

    private static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return formatter
    }()

    static func parse(_ raw: String?) -> Date? {
        guard let raw else { return nil }
        return withFractionalSeconds.date(from: raw) ?? plain.date(from: raw)
    }

    /// "09:00 AM" -- what sits under a chat bubble, matching the web app.
    static func clockTime(_ raw: String?) -> String? {
        parse(raw).map { clock.string(from: $0) }
    }

    /// Time for today, weekday within the last week, date before that. This is
    /// the form a list of rows wants: precise where precision is useful,
    /// coarse where it isn't.
    static func listTime(_ raw: String?) -> String? {
        guard let date = parse(raw) else { return nil }
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return clock.string(from: date) }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        if let weekAgo = calendar.date(byAdding: .day, value: -6, to: Date()), date > weekAgo {
            return weekday.string(from: date)
        }
        return shortDate.string(from: date)
    }

    /// "2:14" between two timestamps. Nil when either end is missing, which is
    /// the normal state of a call that was never answered.
    static func duration(from start: String?, to end: String?) -> String? {
        guard let start = parse(start), let end = parse(end) else { return nil }
        let seconds = max(0, Int(end.timeIntervalSince(start)))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    /// Day heading over a run of messages: "Today", "Yesterday", then a date.
    static func dayLabel(_ raw: String?) -> String? {
        guard let date = parse(raw) else { return nil }
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        return shortDate.string(from: date)
    }
}
