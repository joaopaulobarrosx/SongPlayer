import Testing
import Foundation
@testable import SongPlayer

// MARK: - Mock Network Service

struct MockNetworkService: NetworkServiceProtocol {
    var searchResult: iTunesSearchResponse?
    var lookupResult: iTunesSearchResponse?
    var error: Error?

    func searchSongs(term: String, offset: Int, limit: Int) async throws -> iTunesSearchResponse {
        if let error { throw error }
        return searchResult ?? iTunesSearchResponse(resultCount: 0, results: [])
    }

    func lookupAlbum(collectionId: Int) async throws -> iTunesSearchResponse {
        if let error { throw error }
        return lookupResult ?? iTunesSearchResponse(resultCount: 0, results: [])
    }
}

// MARK: - Test Data

extension Song {
    static func mock(
        trackId: Int = 1,
        trackName: String = "Test Song",
        artistName: String = "Test Artist",
        collectionName: String? = "Test Album",
        collectionId: Int? = 100,
        artworkUrl100: String? = "https://example.com/100x100bb.jpg",
        previewUrl: String? = "https://example.com/preview.m4a",
        trackTimeMillis: Int? = 210000,
        trackNumber: Int? = 1
    ) -> Song {
        Song(
            trackId: trackId,
            trackName: trackName,
            artistName: artistName,
            collectionName: collectionName,
            collectionId: collectionId,
            artworkUrl100: artworkUrl100,
            previewUrl: previewUrl,
            trackTimeMillis: trackTimeMillis,
            trackNumber: trackNumber,
            discNumber: 1,
            collectionPrice: nil,
            trackPrice: nil,
            primaryGenreName: "Pop",
            releaseDate: nil
        )
    }
}

// MARK: - Song Model Tests

@Suite("Song Model")
struct SongModelTests {
    @Test("formatted duration shows correct time")
    func formattedDuration() {
        let song = Song.mock(trackTimeMillis: 210000) // 3:30
        #expect(song.formattedDuration == "3:30")
    }

    @Test("formatted duration with nil millis shows placeholder")
    func formattedDurationNil() {
        let song = Song.mock(trackTimeMillis: nil)
        #expect(song.formattedDuration == "--:--")
    }

    @Test("artwork URL large replaces size")
    func artworkUrlLarge() {
        let song = Song.mock(artworkUrl100: "https://example.com/100x100bb.jpg")
        #expect(song.artworkUrlLarge == "https://example.com/600x600bb.jpg")
    }

    @Test("artwork URL large with nil returns nil")
    func artworkUrlLargeNil() {
        let song = Song.mock(artworkUrl100: nil)
        #expect(song.artworkUrlLarge == nil)
    }

    @Test("song id matches trackId")
    func songId() {
        let song = Song.mock(trackId: 42)
        #expect(song.id == 42)
    }

    @Test("song is decodable from JSON")
    func songDecoding() throws {
        let json = """
        {
            "trackId": 123,
            "trackName": "Get Lucky",
            "artistName": "Daft Punk",
            "collectionName": "Random Access Memories",
            "collectionId": 456,
            "artworkUrl100": "https://example.com/100x100bb.jpg",
            "previewUrl": "https://example.com/preview.m4a",
            "trackTimeMillis": 369000,
            "trackNumber": 8,
            "discNumber": 1,
            "primaryGenreName": "Electronic"
        }
        """.data(using: .utf8)!

        let song = try JSONDecoder().decode(Song.self, from: json)
        #expect(song.trackId == 123)
        #expect(song.trackName == "Get Lucky")
        #expect(song.artistName == "Daft Punk")
        #expect(song.collectionName == "Random Access Memories")
        #expect(song.formattedDuration == "6:09")
    }

    @Test("iTunes search response is decodable")
    func searchResponseDecoding() throws {
        let json = """
        {
            "resultCount": 1,
            "results": [{
                "trackId": 1,
                "trackName": "Song",
                "artistName": "Artist",
                "trackTimeMillis": 60000
            }]
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(iTunesSearchResponse.self, from: json)
        #expect(response.resultCount == 1)
        #expect(response.results.count == 1)
        #expect(response.results[0].trackName == "Song")
    }
}

// MARK: - API Endpoint Tests

@Suite("API Endpoint")
struct APIEndpointTests {
    @Test("search endpoint builds correct URL")
    func searchURL() {
        let endpoint = APIEndpoint.searchSongs(term: "daft punk", offset: 0, limit: 25)
        let url = endpoint.url!
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)!

        #expect(components.scheme == "https")
        #expect(components.host == "itunes.apple.com")
        #expect(components.path == "/search")

        let queryItems = components.queryItems ?? []
        #expect(queryItems.contains(URLQueryItem(name: "term", value: "daft punk")))
        #expect(queryItems.contains(URLQueryItem(name: "media", value: "music")))
        #expect(queryItems.contains(URLQueryItem(name: "entity", value: "song")))
        #expect(queryItems.contains(URLQueryItem(name: "offset", value: "0")))
        #expect(queryItems.contains(URLQueryItem(name: "limit", value: "25")))
    }

    @Test("lookup endpoint builds correct URL")
    func lookupURL() {
        let endpoint = APIEndpoint.lookupAlbum(collectionId: 456)
        let url = endpoint.url!
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)!

        #expect(components.path == "/lookup")
        let queryItems = components.queryItems ?? []
        #expect(queryItems.contains(URLQueryItem(name: "id", value: "456")))
        #expect(queryItems.contains(URLQueryItem(name: "entity", value: "song")))
    }

    @Test("search endpoint with offset for pagination")
    func searchWithOffset() {
        let endpoint = APIEndpoint.searchSongs(term: "test", offset: 50, limit: 25)
        let url = endpoint.url!
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        let queryItems = components.queryItems ?? []
        #expect(queryItems.contains(URLQueryItem(name: "offset", value: "50")))
    }
}

// MARK: - SongsViewModel Tests

@Suite("SongsViewModel")
@MainActor
struct SongsViewModelTests {
    @Test("initial state is idle")
    func initialState() {
        let vm = SongsViewModel()
        if case .idle = vm.state {
            // pass
        } else {
            Issue.record("Expected idle state")
        }
        #expect(vm.songs.isEmpty)
    }

    @Test("search with empty text resets state")
    func searchEmptyText() {
        let vm = SongsViewModel()
        vm.searchText = ""
        vm.searchSongs()

        if case .idle = vm.state {
            // pass
        } else {
            Issue.record("Expected idle state")
        }
    }

    @Test("search with text triggers loading")
    func searchWithText() async throws {
        let mockSongs = [Song.mock(trackId: 1), Song.mock(trackId: 2)]
        let mock = MockNetworkService(
            searchResult: iTunesSearchResponse(resultCount: 2, results: mockSongs)
        )
        let vm = SongsViewModel(networkService: mock)
        vm.searchText = "test"
        vm.searchSongs()

        try await Task.sleep(for: .milliseconds(100))

        if case .loaded = vm.state {
            // pass
        } else {
            Issue.record("Expected loaded state, got \(vm.state)")
        }
        #expect(vm.songs.count == 2)
    }

    @Test("search error sets error state")
    func searchError() async throws {
        let mock = MockNetworkService(error: NetworkError.noConnection)
        let vm = SongsViewModel(networkService: mock)
        vm.searchText = "test"
        vm.searchSongs()

        try await Task.sleep(for: .milliseconds(100))

        if case .error = vm.state {
            // pass
        } else {
            Issue.record("Expected error state")
        }
    }

    @Test("pagination sets hasMoreResults correctly")
    func paginationComplete() async throws {
        let mockSongs = [Song.mock(trackId: 1)]
        let mock = MockNetworkService(
            searchResult: iTunesSearchResponse(resultCount: 1, results: mockSongs)
        )
        let vm = SongsViewModel(networkService: mock)
        vm.searchText = "test"
        vm.searchSongs()

        try await Task.sleep(for: .milliseconds(100))

        #expect(vm.hasMoreResults == false)
    }
}

// MARK: - AlbumViewModel Tests

@Suite("AlbumViewModel")
@MainActor
struct AlbumViewModelTests {
    @Test("initial state is loading")
    func initialState() {
        let vm = AlbumViewModel()
        if case .loading = vm.state {
            // pass
        } else {
            Issue.record("Expected loading state")
        }
    }

    @Test("load album populates songs")
    func loadAlbum() async {
        let songs = [
            Song.mock(trackId: 1, trackName: "Track 1", trackTimeMillis: 200000),
            Song.mock(trackId: 2, trackName: "Track 2", trackTimeMillis: 180000),
        ]
        let mock = MockNetworkService(
            lookupResult: iTunesSearchResponse(resultCount: 2, results: songs)
        )
        let vm = AlbumViewModel(networkService: mock)

        await vm.loadAlbum(collectionId: 100)

        if case .loaded = vm.state {
            // pass
        } else {
            Issue.record("Expected loaded state")
        }
        #expect(vm.songs.count == 2)
    }

    @Test("load album error sets error state")
    func loadAlbumError() async {
        let mock = MockNetworkService(error: NetworkError.invalidURL)
        let vm = AlbumViewModel(networkService: mock)

        await vm.loadAlbum(collectionId: 100)

        if case .error = vm.state {
            // pass
        } else {
            Issue.record("Expected error state")
        }
    }
}

// MARK: - CachedSong Tests

@Suite("CachedSong")
struct CachedSongTests {
    @Test("CachedSong converts from Song correctly")
    func fromSong() {
        let song = Song.mock(
            trackId: 42,
            trackName: "Test",
            artistName: "Artist",
            collectionName: "Album"
        )
        let cached = CachedSong(from: song)

        #expect(cached.trackId == 42)
        #expect(cached.trackName == "Test")
        #expect(cached.artistName == "Artist")
        #expect(cached.collectionName == "Album")
        #expect(cached.lastPlayedAt == nil)
    }

    @Test("CachedSong converts back to Song")
    func toSong() {
        let original = Song.mock(trackId: 99, trackName: "Round Trip")
        let cached = CachedSong(from: original)
        let converted = cached.toSong()

        #expect(converted.trackId == 99)
        #expect(converted.trackName == "Round Trip")
        #expect(converted.artistName == original.artistName)
    }
}

// MARK: - NetworkError Tests

@Suite("NetworkError")
struct NetworkErrorTests {
    @Test("error descriptions are user-friendly")
    func errorDescriptions() {
        #expect(NetworkError.invalidURL.errorDescription == "Invalid URL")
        #expect(NetworkError.noConnection.errorDescription == "No internet connection")
        #expect(NetworkError.httpError(statusCode: 500).errorDescription == "Server error (HTTP 500)")
        #expect(NetworkError.invalidResponse.errorDescription == "Invalid response from server")
    }
}
