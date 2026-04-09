import Foundation

public protocol NetworkServiceProtocol: Sendable {
    func searchSongs(term: String, offset: Int, limit: Int) async throws -> iTunesSearchResponse
    func lookupAlbum(collectionId: Int) async throws -> iTunesSearchResponse
}

public enum NetworkError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case decodingError(Error)
    case noConnection

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            "Invalid URL"
        case .invalidResponse:
            "Invalid response from server"
        case .httpError(let statusCode):
            "Server error (HTTP \(statusCode))"
        case .decodingError:
            "Failed to parse response"
        case .noConnection:
            "No internet connection"
        }
    }
}
