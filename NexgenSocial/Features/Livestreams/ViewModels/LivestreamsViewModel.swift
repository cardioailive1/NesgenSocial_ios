import Foundation

@MainActor
final class LivestreamsViewModel: ObservableObject, LoadingViewModel {
    @Published private(set) var streams: [Livestream] = []
    @Published var newTitle = ""
    @Published var watching: Livestream?
    @Published var errorMessage: String?

    func load() async {
        await attempt {
            streams = try await LivestreamsService.all()
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
