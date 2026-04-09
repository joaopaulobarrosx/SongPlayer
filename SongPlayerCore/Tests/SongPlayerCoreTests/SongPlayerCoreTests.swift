import Testing
import Foundation
@testable import SongPlayerCore

@Suite("SongPlayerCore smoke tests")
struct SongPlayerCoreSmokeTests {
    @Test("Song formatted duration")
    func formattedDuration() {
        let song = Song(
            trackId: 1, trackName: "T", artistName: "A",
            collectionName: nil, collectionId: nil,
            artworkUrl100: nil, previewUrl: nil,
            trackTimeMillis: 210_000, trackNumber: nil, discNumber: nil,
            collectionPrice: nil, trackPrice: nil,
            primaryGenreName: nil, releaseDate: nil
        )
        #expect(song.formattedDuration == "3:30")
    }

    @Test("APIEndpoint builds search URL")
    func searchURL() {
        let url = APIEndpoint.searchSongs(term: "ed", offset: 0, limit: 25).url!
        #expect(url.host == "itunes.apple.com")
        #expect(url.path == "/search")
    }
}
