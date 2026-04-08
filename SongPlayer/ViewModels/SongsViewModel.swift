import Foundation
import SwiftData

@MainActor
@Observable
final class SongsViewModel {
    enum State: Equatable {
        case idle
        case loading
        case loaded
        case offline
        case error(String)
    }

    private(set) var songs: [Song] = []
    private(set) var recentlyPlayed: [Song] = []
    private(set) var state: State = .idle
    private(set) var hasMoreResults = true

    var searchText: String = "" {
        didSet { scheduleDebounce() }
    }

    private let networkService: NetworkServiceProtocol
    private let pageSize = 25
    private var currentOffset = 0
    private var searchTask: Task<Void, Never>?
    private var debounceTask: Task<Void, Never>?

    init(networkService: NetworkServiceProtocol = NetworkService()) {
        self.networkService = networkService
    }

    private func scheduleDebounce() {
        debounceTask?.cancel()

        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            searchSongs()
            return
        }

        debounceTask = Task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            searchSongs()
        }
    }

    func searchSongs() {
        debounceTask?.cancel()
        searchTask?.cancel()
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            songs = []
            state = .idle
            currentOffset = 0
            hasMoreResults = true
            return
        }

        currentOffset = 0
        hasMoreResults = true

        searchTask = Task {
            state = .loading
            do {
                let response = try await networkService.searchSongs(
                    term: trimmed,
                    offset: 0,
                    limit: pageSize
                )
                guard !Task.isCancelled else { return }
                songs = response.results
                currentOffset = response.results.count
                hasMoreResults = response.results.count >= pageSize
                state = .loaded
            } catch is CancellationError {
                // Cancelled — ignore
            } catch {
                guard !Task.isCancelled else { return }
                if case NetworkError.noConnection = error {
                    state = .offline
                } else {
                    state = .error(error.localizedDescription)
                }
            }
        }
    }

    func loadMoreIfNeeded(currentSong: Song) {
        guard let lastSong = songs.last,
              lastSong.id == currentSong.id,
              hasMoreResults,
              searchTask == nil || searchTask?.isCancelled == true
        else { return }

        loadNextPage()
    }

    func loadNextPage() {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, hasMoreResults else { return }

        searchTask = Task {
            do {
                let response = try await networkService.searchSongs(
                    term: trimmed,
                    offset: currentOffset,
                    limit: pageSize
                )
                guard !Task.isCancelled else { return }
                songs.append(contentsOf: response.results)
                currentOffset += response.results.count
                hasMoreResults = response.results.count >= pageSize
            } catch is CancellationError {
                // Cancelled
            } catch {
                // Silently fail pagination
            }
        }
    }

    func loadRecentlyPlayed(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<CachedSong>(
            predicate: #Predicate { $0.lastPlayedAt != nil },
            sortBy: [SortDescriptor(\.lastPlayedAt, order: .reverse)]
        )
        if let cached = try? modelContext.fetch(descriptor) {
            recentlyPlayed = cached.prefix(20).map { $0.toSong() }
        }
    }

    func markAsPlayed(song: Song, modelContext: ModelContext) {
        let trackId = song.trackId
        let descriptor = FetchDescriptor<CachedSong>(
            predicate: #Predicate { $0.trackId == trackId }
        )

        if let existing = try? modelContext.fetch(descriptor).first {
            existing.lastPlayedAt = Date()
        } else {
            let cached = CachedSong(from: song)
            cached.lastPlayedAt = Date()
            modelContext.insert(cached)
        }

        try? modelContext.save()
    }

    func removeRecentlyPlayed(song: Song, modelContext: ModelContext) {
        let trackId = song.trackId
        let descriptor = FetchDescriptor<CachedSong>(
            predicate: #Predicate { $0.trackId == trackId }
        )
        if let cached = try? modelContext.fetch(descriptor).first {
            modelContext.delete(cached)
            try? modelContext.save()
        }
        recentlyPlayed.removeAll { $0.id == song.id }
    }

    func cacheSongs(_ songs: [Song], modelContext: ModelContext) {
        for song in songs {
            let trackId = song.trackId
            let descriptor = FetchDescriptor<CachedSong>(
                predicate: #Predicate { $0.trackId == trackId }
            )
            if (try? modelContext.fetch(descriptor).first) == nil {
                modelContext.insert(CachedSong(from: song))
            }
        }
        try? modelContext.save()
    }
}
