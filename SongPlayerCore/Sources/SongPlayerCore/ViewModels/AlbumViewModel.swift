import Foundation

@MainActor
@Observable
public final class AlbumViewModel {
    public enum State {
        case loading
        case loaded
        case offline
        case error(String)
    }

    public private(set) var songs: [Song] = []
    public private(set) var state: State = .loading

    private let networkService: NetworkServiceProtocol

    public init(networkService: NetworkServiceProtocol = NetworkService()) {
        self.networkService = networkService
    }

    public func loadAlbum(collectionId: Int) async {
        state = .loading
        do {
            let response = try await networkService.lookupAlbum(collectionId: collectionId)
            let tracks = response.results.filter { $0.trackTimeMillis != nil }
            songs = tracks.sorted {
                ($0.discNumber ?? 0, $0.trackNumber ?? 0) < ($1.discNumber ?? 0, $1.trackNumber ?? 0)
            }
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
