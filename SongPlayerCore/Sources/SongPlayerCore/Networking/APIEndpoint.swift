import Foundation

public enum APIEndpoint: Sendable {
    case searchSongs(term: String, offset: Int, limit: Int)
    case lookupAlbum(collectionId: Int)

    public var url: URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "itunes.apple.com"

        switch self {
        case .searchSongs(let term, let offset, let limit):
            components.path = "/search"
            components.queryItems = [
                URLQueryItem(name: "term", value: term),
                URLQueryItem(name: "media", value: "music"),
                URLQueryItem(name: "entity", value: "song"),
                URLQueryItem(name: "offset", value: String(offset)),
                URLQueryItem(name: "limit", value: String(limit))
            ]
        case .lookupAlbum(let collectionId):
            components.path = "/lookup"
            components.queryItems = [
                URLQueryItem(name: "id", value: String(collectionId)),
                URLQueryItem(name: "entity", value: "song")
            ]
        }

        return components.url
    }
}
