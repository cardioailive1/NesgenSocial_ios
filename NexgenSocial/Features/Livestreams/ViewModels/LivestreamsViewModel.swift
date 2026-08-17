import Foundation

@MainActor
final class LivestreamsViewModel: ObservableObject {
    @Published private(set) var streams: [Livestream] = []
    @Published var newTitle = ""
    @Published var watching: Livestream?
    @Published var errorMessage: String?

    func load() async {
        do {
            streams = try await LivestreamsService.all()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func start() async {
        let title = newTitle
        newTitle = ""
        do {
            let stream = try await LivestreamsService.start(title: title)
            await load()
            watching = stream
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
