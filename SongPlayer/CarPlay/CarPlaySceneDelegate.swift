import CarPlay
import SwiftData
import UIKit

/// Root of the CarPlay experience. Shows Recently Played as a list,
/// plays a tapped song via the shared `AudioPlayerService`, then hands
/// control to the system `CPNowPlayingTemplate`. A custom Now Playing
/// button pushes the current song's album as a second list template.
@MainActor
final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    private var interfaceController: CPInterfaceController?
    private let networkService: NetworkServiceProtocol = NetworkService()

    // MARK: - Scene lifecycle

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = interfaceController
        interfaceController.setRootTemplate(makeRecentlyPlayedTemplate(), animated: false, completion: nil)
        configureNowPlayingAlbumButton()
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = nil
    }

    // MARK: - Recently played (root)

    private func makeRecentlyPlayedTemplate() -> CPListTemplate {
        let songs = fetchRecentlyPlayed()
        let items = songs.map { song -> CPListItem in
            let item = CPListItem(text: song.trackName, detailText: song.artistName)
            loadArtwork(for: song, into: item)
            item.handler = { [weak self] _, completion in
                Task { @MainActor in
                    AudioPlayerService.shared.play(song: song, playlist: songs, index: songs.firstIndex(where: { $0.id == song.id }) ?? 0)
                    self?.pushNowPlaying()
                    completion()
                }
            }
            return item
        }
        let section = CPListSection(items: items)
        return CPListTemplate(title: NSLocalizedString("Recently Played", comment: ""), sections: [section])
    }

    private func fetchRecentlyPlayed() -> [Song] {
        guard let container = try? ModelContainer(for: CachedSong.self) else { return [] }
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<CachedSong>(
            predicate: #Predicate { $0.lastPlayedAt != nil },
            sortBy: [SortDescriptor(\.lastPlayedAt, order: .reverse)]
        )
        guard let cached = try? context.fetch(descriptor) else { return [] }
        return cached.prefix(30).map { $0.toSong() }
    }

    // MARK: - Now Playing + album button

    private func pushNowPlaying() {
        let template = CPNowPlayingTemplate.shared
        interfaceController?.pushTemplate(template, animated: true, completion: nil)
    }

    private func configureNowPlayingAlbumButton() {
        let albumButton = CPNowPlayingImageButton(image: UIImage(systemName: "square.stack") ?? UIImage()) { [weak self] _ in
            Task { @MainActor in
                await self?.pushAlbumForCurrentSong()
            }
        }
        CPNowPlayingTemplate.shared.updateNowPlayingButtons([albumButton])
    }

    private func pushAlbumForCurrentSong() async {
        guard let collectionId = AudioPlayerService.shared.currentSong?.collectionId else { return }
        do {
            let response = try await networkService.lookupAlbum(collectionId: collectionId)
            let tracks = response.results.filter { $0.trackTimeMillis != nil }
            let template = makeAlbumTemplate(songs: tracks)
            interfaceController?.pushTemplate(template, animated: true, completion: nil)
        } catch {
            // Offline or failure — silently ignore; the Now Playing screen stays.
        }
    }

    private func makeAlbumTemplate(songs: [Song]) -> CPListTemplate {
        let items = songs.map { song -> CPListItem in
            let item = CPListItem(text: song.trackName, detailText: song.artistName)
            loadArtwork(for: song, into: item)
            item.handler = { _, completion in
                Task { @MainActor in
                    AudioPlayerService.shared.play(song: song, playlist: songs, index: songs.firstIndex(where: { $0.id == song.id }) ?? 0)
                    completion()
                }
            }
            return item
        }
        let title = songs.first?.collectionName ?? NSLocalizedString("Album", comment: "")
        return CPListTemplate(title: title, sections: [CPListSection(items: items)])
    }

    // MARK: - Artwork loading

    private func loadArtwork(for song: Song, into item: CPListItem) {
        guard let urlString = song.artworkUrl100, let url = URL(string: urlString) else { return }
        let localURL = MediaCacheService.shared.localURL(for: url, kind: .image)
        Task.detached {
            var data: Data?
            if let localURL {
                // Disk read — cheap, fine off the main thread.
                data = try? Data(contentsOf: localURL)
            }
            if data == nil {
                data = try? await URLSession.shared.data(from: url).0
            }
            guard let data, let image = UIImage(data: data) else { return }
            await MainActor.run { item.setImage(image) }
        }
    }
}
