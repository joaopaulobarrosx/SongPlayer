import Foundation

public struct iTunesSearchResponse: Codable, Sendable {
    public let resultCount: Int
    public let results: [Song]

    enum CodingKeys: String, CodingKey {
        case resultCount, results
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.resultCount = (try? container.decode(Int.self, forKey: .resultCount)) ?? 0
        var results: [Song] = []
        var arrayContainer = try container.nestedUnkeyedContainer(forKey: .results)
        while !arrayContainer.isAtEnd {
            if let song = try? arrayContainer.decode(Song.self) {
                results.append(song)
            } else {
                _ = try? arrayContainer.decode(AnyDecodable.self)
            }
        }
        self.results = results
    }

    public init(resultCount: Int, results: [Song]) {
        self.resultCount = resultCount
        self.results = results
    }
}

private struct AnyDecodable: Decodable {}

public struct Song: Codable, Sendable, Identifiable, Hashable {
    public let trackId: Int
    public let trackName: String
    public let artistName: String
    public let collectionName: String?
    public let collectionId: Int?
    public let artworkUrl100: String?
    public let previewUrl: String?
    public let trackTimeMillis: Int?
    public let trackNumber: Int?
    public let discNumber: Int?
    public let collectionPrice: Double?
    public let trackPrice: Double?
    public let primaryGenreName: String?
    public let releaseDate: String?

    public var id: Int { trackId }

    public var artworkUrlLarge: String? {
        artworkUrl100?.replacingOccurrences(of: "100x100", with: "600x600")
    }

    public init(
        trackId: Int,
        trackName: String,
        artistName: String,
        collectionName: String?,
        collectionId: Int?,
        artworkUrl100: String?,
        previewUrl: String?,
        trackTimeMillis: Int?,
        trackNumber: Int?,
        discNumber: Int?,
        collectionPrice: Double?,
        trackPrice: Double?,
        primaryGenreName: String?,
        releaseDate: String?
    ) {
        self.trackId = trackId
        self.trackName = trackName
        self.artistName = artistName
        self.collectionName = collectionName
        self.collectionId = collectionId
        self.artworkUrl100 = artworkUrl100
        self.previewUrl = previewUrl
        self.trackTimeMillis = trackTimeMillis
        self.trackNumber = trackNumber
        self.discNumber = discNumber
        self.collectionPrice = collectionPrice
        self.trackPrice = trackPrice
        self.primaryGenreName = primaryGenreName
        self.releaseDate = releaseDate
    }

    public static let placeholder = Song(
        trackId: 0, trackName: "", artistName: "",
        collectionName: nil, collectionId: nil, artworkUrl100: nil,
        previewUrl: nil, trackTimeMillis: nil, trackNumber: nil,
        discNumber: nil, collectionPrice: nil, trackPrice: nil,
        primaryGenreName: nil, releaseDate: nil
    )

    public var formattedDuration: String {
        guard let millis = trackTimeMillis else { return "--:--" }
        let totalSeconds = millis / 1000
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
