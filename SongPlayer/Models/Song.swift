import Foundation

nonisolated struct iTunesSearchResponse: Codable, Sendable {
    let resultCount: Int
    let results: [Song]
}

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

    var formattedDuration: String {
        guard let millis = trackTimeMillis else { return "--:--" }
        let totalSeconds = millis / 1000
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
