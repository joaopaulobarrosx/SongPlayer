import Foundation

public final class NetworkService: NetworkServiceProtocol {
    private let session: URLSession
    private let decoder: JSONDecoder

    public init(session: URLSession = .shared) {
        self.session = session
        self.decoder = JSONDecoder()
    }

    public func searchSongs(term: String, offset: Int, limit: Int) async throws -> iTunesSearchResponse {
        let endpoint = APIEndpoint.searchSongs(term: term, offset: offset, limit: limit)
        return try await request(endpoint: endpoint)
    }

    public func lookupAlbum(collectionId: Int) async throws -> iTunesSearchResponse {
        let endpoint = APIEndpoint.lookupAlbum(collectionId: collectionId)
        return try await request(endpoint: endpoint)
    }

    private func request(endpoint: APIEndpoint) async throws -> iTunesSearchResponse {
        guard let url = endpoint.url else {
            throw NetworkError.invalidURL
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(from: url)
        } catch let error as URLError where error.code == .notConnectedToInternet || error.code == .networkConnectionLost {
            throw NetworkError.noConnection
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.httpError(statusCode: httpResponse.statusCode)
        }

        do {
            return try decoder.decode(iTunesSearchResponse.self, from: data)
        } catch {
            throw NetworkError.decodingError(error)
        }
    }
}
