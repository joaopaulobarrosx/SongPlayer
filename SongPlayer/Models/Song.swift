import Foundation

nonisolated struct iTunesSearchResponse: Codable, Sendable {
    let resultCount: Int
    let results: [Song]

    enum CodingKeys: String, CodingKey {
        case resultCount, results
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.resultCount = (try? container.decode(Int.self, forKey: .resultCount)) ?? 0
        // Lookup endpoint mixes a collection entry with track entries; decode leniently and skip failures.
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

    init(resultCount: Int, results: [Song]) {
        self.resultCount = resultCount
        self.results = results
    }
}

nonisolated private struct AnyDecodable: Decodable {}

nonisolated struct Song: Codable, Sendable, Identifiable, Hashable {
    let trackId: Int
    let trackName: String
    let artistName: String
    let collectionName: String?
    let collectionId: Int?
    let artworkUrl100: String?
    let previewUrl: String?
    let trackTimeMillis: Int?
    let trackNumber: Int?
    let discNumber: Int?
    let collectionPrice: Double?
    let trackPrice: Double?
    let primaryGenreName: String?
    let releaseDate: String?

    var id: Int { trackId }

    var artworkUrlLarge: String? {
        artworkUrl100?.replacingOccurrences(of: "100x100", with: "600x600")
    }

    static let placeholder = Song(
        trackId: 0, trackName: "", artistName: "",
        collectionName: nil, collectionId: nil, artworkUrl100: nil,
        previewUrl: nil, trackTimeMillis: nil, trackNumber: nil,
        discNumber: nil, collectionPrice: nil, trackPrice: nil,
        primaryGenreName: nil, releaseDate: nil
    )

    var formattedDuration: String {
        guard let millis = trackTimeMillis else { return "--:--" }
        let totalSeconds = millis / 1000
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
