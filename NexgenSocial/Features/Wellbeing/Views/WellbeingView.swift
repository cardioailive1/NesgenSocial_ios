import SwiftUI

/// Screen time, counted on the device and stored in UserDefaults. Nothing
/// here is sent anywhere: the point of the screen is to show someone their
/// own usage, and shipping that number to a server would undercut it.
enum ScreenTime {
    private static let key = "ngs_screentime"

    private static var dayKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    static func read() -> [String: Int] {
        UserDefaults.standard.dictionary(forKey: key) as? [String: Int] ?? [:]
    }

    static func add(seconds: Int) {
        var data = read()
        data[dayKey] = (data[dayKey] ?? 0) + seconds
        // Older than a fortnight is never displayed, so it's never kept.
        let cutoff = Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let cutoffKey = formatter.string(from: cutoff)
        UserDefaults.standard.set(data.filter { $0.key >= cutoffKey }, forKey: key)
    }
}

/// Accumulates foreground seconds. Records the elapsed span on the way to
/// the background rather than ticking every second, so it costs nothing
/// while the app is open.
@MainActor
final class ScreenTimeTracker: ObservableObject {
    static let shared = ScreenTimeTracker()
    private var enteredForegroundAt: Date?

    func begin() { enteredForegroundAt = Date() }

    func end() {
        guard let start = enteredForegroundAt else { return }
        ScreenTime.add(seconds: Int(Date().timeIntervalSince(start)))
        enteredForegroundAt = nil
    }
}

struct WellbeingView: View {
    @State private var days: [(label: String, key: String, seconds: Int)] = []

    var body: some View {
        ZStack {
            Theme.navy950.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Counted on this device only — never sent to a server, never used to target ads. The feed also has no infinite scroll: it loads a fixed batch and stops, on purpose.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.slate400)

                    VStack(spacing: 4) {
                        Text("TODAY")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Theme.slate400)
                        Text(format(days.last?.seconds ?? 0))
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity)
                    .card()

                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader("Last 7 days")
                        HStack(alignment: .bottom, spacing: 10) {
                            ForEach(days, id: \.key) { day in
                                VStack(spacing: 6) {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Theme.cyan400)
                                        .frame(height: barHeight(day.seconds))
                                    Text(day.label)
                                        .font(.system(size: 11))
                                        .foregroundStyle(Theme.slate400)
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                        .frame(height: 140, alignment: .bottom)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card()
                }
                .padding(14)
            }
        }
        .navigationTitle("Your time here")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: rebuild)
    }

    private func barHeight(_ seconds: Int) -> CGFloat {
        let peak = max(days.map(\.seconds).max() ?? 60, 60)
        return max(4, CGFloat(seconds) / CGFloat(peak) * 110)
    }

    private func format(_ seconds: Int) -> String {
        let minutes = Int((Double(seconds) / 60).rounded())
        return minutes < 1 ? "<1 min" : "\(minutes) min"
    }

    private func rebuild() {
        let data = ScreenTime.read()
        let keyFormatter = DateFormatter()
        keyFormatter.dateFormat = "yyyy-MM-dd"
        let labelFormatter = DateFormatter()
        labelFormatter.dateFormat = "EEE"

        days = (0..<7).reversed().compactMap { offset in
            guard let date = Calendar.current.date(byAdding: .day, value: -offset, to: Date()) else { return nil }
            let key = keyFormatter.string(from: date)
            return (labelFormatter.string(from: date), key, data[key] ?? 0)
        }
    }
}
