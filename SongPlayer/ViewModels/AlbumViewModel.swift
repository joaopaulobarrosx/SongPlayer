import Foundation

@MainActor
@Observable
final class AlbumViewModel {
    enum State {
        case loading
        case loaded
        case offline
        case error(String)
    }

    private(set) var songs: [Song] = []
    private(set) var state: State = .loading

    private let networkService: NetworkServiceProtocol

    init(networkService: NetworkServiceProtocol = NetworkService()) {
        self.networkService = networkService
    }

    func loadAlbum(collectionId: Int) async {
        state = .loading
        do {
            let response = try await networkService.lookupAlbum(collectionId: collectionId)
            // First result is the collection itself, rest are tracks
            songs = response.results.filter { $0.trackTimeMillis != nil }
            songs.sort { ($0.discNumber ?? 0, $0.trackNumber ?? 0) < ($1.discNumber ?? 0, $1.trackNumber ?? 0) }
            state = .loaded
        } catch {
            if case NetworkError.noConnection = error {
                state = .offline
            } else {
                state = .error(error.localizedDescription)
            }
        }
    }
}
