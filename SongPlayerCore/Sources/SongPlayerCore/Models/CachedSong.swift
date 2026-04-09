import Foundation
import SwiftData

@Model
public final class CachedSong {
    @Attribute(.unique) public var trackId: Int
    public var trackName: String
    public var artistName: String
    public var collectionName: String?
    public var collectionId: Int?
    public var artworkUrl100: String?
    public var previewUrl: String?
    public var trackTimeMillis: Int?
    public var trackNumber: Int?
    public var discNumber: Int?
    public var primaryGenreName: String?
    public var releaseDate: String?
    public var lastPlayedAt: Date?
    public var cachedAt: Date

    public init(from song: Song) {
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

    public func toSong() -> Song {
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
