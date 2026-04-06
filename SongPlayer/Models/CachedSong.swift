import Foundation
import SwiftData

@Model
final class CachedSong {
    @Attribute(.unique) var trackId: Int
    var trackName: String
    var artistName: String
    var collectionName: String?
    var collectionId: Int?
    var artworkUrl100: String?
    var previewUrl: String?
    var trackTimeMillis: Int?
    var trackNumber: Int?
    var discNumber: Int?
    var primaryGenreName: String?
    var releaseDate: String?
    var lastPlayedAt: Date?
    var cachedAt: Date

    init(from song: Song) {
        self.trackId = song.trackId
        self.trackName = song.trackName
        self.artistName = song.artistName
        self.collectionName = song.collectionName
        self.collectionId = song.collectionId
        self.artworkUrl100 = song.artworkUrl100
        self.previewUrl = song.previewUrl
        self.trackTimeMillis = song.trackTimeMillis
        self.trackNumber = song.trackNumber
        self.discNumber = song.discNumber
        self.primaryGenreName = song.primaryGenreName
        self.releaseDate = song.releaseDate
        self.lastPlayedAt = nil
        self.cachedAt = Date()
    }

    func toSong() -> Song {
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
            discNumber: discNumber,
            collectionPrice: nil,
            trackPrice: nil,
            primaryGenreName: primaryGenreName,
            releaseDate: releaseDate
        )
    }
}
