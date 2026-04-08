import Foundation
import CryptoKit

nonisolated protocol MediaCacheServiceProtocol: Sendable {
    func localURL(for remoteURL: URL, kind: MediaCacheService.Kind) -> URL?
    func download(_ remoteURL: URL, kind: MediaCacheService.Kind) async throws -> URL
}

/// File-based cache for artwork images and audio previews so the app
/// works fully offline once a song has been played at least once.
///
/// All stored properties are `Sendable` value/reference types whose
/// underlying APIs (`URLSession`, `FileManager`) are documented thread-safe,
/// so this type is safely `Sendable` without `@unchecked`.
nonisolated final class MediaCacheService: MediaCacheServiceProtocol, Sendable {
    enum Kind {
        case image
        case audio

        var folder: String {
            switch self {
            case .image: "Artwork"
            case .audio: "Audio"
            }
        }

        var fileExtension: String {
            switch self {
            case .image: "img"
            case .audio: "m4a"
            }
        }
    }

    static let shared = MediaCacheService()

    private let session: URLSession
    private let baseURL: URL

    init(session: URLSession = .shared) {
        self.session = session
        let support = (try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? FileManager.default.temporaryDirectory
        self.baseURL = support.appendingPathComponent("MediaCache", isDirectory: true)
        for kind in [Kind.image, Kind.audio] {
            let dir = baseURL.appendingPathComponent(kind.folder, isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }

    private func fileURL(for remoteURL: URL, kind: Kind) -> URL {
        let digest = SHA256.hash(data: Data(remoteURL.absoluteString.utf8))
        let name = digest.compactMap { String(format: "%02x", $0) }.joined()
        return baseURL
            .appendingPathComponent(kind.folder, isDirectory: true)
            .appendingPathComponent("\(name).\(kind.fileExtension)")
    }

    func localURL(for remoteURL: URL, kind: Kind) -> URL? {
        let url = fileURL(for: remoteURL, kind: kind)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    @discardableResult
    func download(_ remoteURL: URL, kind: Kind) async throws -> URL {
        let destination = fileURL(for: remoteURL, kind: kind)
        if FileManager.default.fileExists(atPath: destination.path) {
            return destination
        }
        let (tempURL, _) = try await session.download(from: remoteURL)
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.moveItem(at: tempURL, to: destination)
        return destination
    }

    /// Fire-and-forget cache of both artwork sizes and the preview audio for a song.
    func prefetch(song: Song) {
        let urls: [(String?, Kind)] = [
            (song.artworkUrl100, .image),
            (song.artworkUrlLarge, .image),
            (song.previewUrl, .audio),
        ]
        for (string, kind) in urls {
            guard let string, let url = URL(string: string) else { continue }
            if localURL(for: url, kind: kind) != nil { continue }
            Task.detached { [weak self] in
                _ = try? await self?.download(url, kind: kind)
            }
        }
    }
}
