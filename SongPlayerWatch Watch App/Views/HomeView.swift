import SwiftUI
import SwiftData
import SongPlayerCore

/// Watch home. Search bar on top, Recently Played below (when no active
/// search), synced from the paired iPhone via WatchConnectivity. Stores a
/// local copy in SwiftData so the Watch stays usable offline.
struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var audioPlayer: WatchAudioPlayerService
    @Bindable var connectivity: WatchConnectivityService

    @State private var viewModel = SongsViewModel()
    @State private var navigateToSong: Song?
    @State private var navigateToAlbum: Int?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Search", text: $viewModel.searchText)
                        .textFieldStyle(.plain)
                        .submitLabel(.search)
                        .onSubmit { viewModel.searchSongs() }
                }

                if !viewModel.songs.isEmpty {
                    ForEach(viewModel.songs) { song in
                        songRow(song, playlist: viewModel.songs)
                            .onAppear { viewModel.loadMoreIfNeeded(currentSong: song) }
                    }
                } else if viewModel.searchText.isEmpty && !viewModel.recentlyPlayed.isEmpty {
                    ForEach(viewModel.recentlyPlayed) { song in
                        songRow(song, playlist: viewModel.recentlyPlayed)
                    }
                }

                switch viewModel.state {
                case .loading:
                    HStack { Spacer(); ProgressView(); Spacer() }
                case .offline:
                    statusRow(icon: "wifi.slash", text: "No internet")
                case .error(let message):
                    Text(message)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                default:
                    EmptyView()
                }

                // Empty state when nothing to show at all.
                if viewModel.songs.isEmpty
                    && viewModel.recentlyPlayed.isEmpty
                    && viewModel.searchText.isEmpty
                    && viewModel.state != .loading {
                    emptyState
                }
            }
            .navigationTitle("Songs")
            .navigationDestination(item: $navigateToSong) { song in
                PlayerView(audioPlayer: audioPlayer, fallbackSong: song) { collectionId in
                    navigateToAlbum = collectionId
                }
            }
            .navigationDestination(item: $navigateToAlbum) { collectionId in
                AlbumView(collectionId: collectionId, audioPlayer: audioPlayer)
            }
        }
        .onAppear {
            viewModel.loadRecentlyPlayed(modelContext: modelContext)
        }
        .onChange(of: connectivity.updateToken) {
            persistFromPhone(connectivity.latestRecentlyPlayed)
            viewModel.loadRecentlyPlayed(modelContext: modelContext)
        }
    }

    // MARK: - Row

    private func songRow(_ song: Song, playlist: [Song]) -> some View {
        Button {
            let index = playlist.firstIndex(where: { $0.id == song.id }) ?? 0
            audioPlayer.play(song: song, playlist: playlist, index: index)
            viewModel.markAsPlayed(song: song, modelContext: modelContext)
            viewModel.cacheSongs(playlist, modelContext: modelContext)
            navigateToSong = song
        } label: {
            HStack(spacing: 8) {
                CachedAsyncImage(url: URL(string: song.artworkUrl100 ?? "")) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.quaternary)
                        .overlay { Image(systemName: "music.note").font(.caption) }
                }
                .frame(width: 32, height: 32)
                .clipShape(RoundedRectangle(cornerRadius: 4))

                VStack(alignment: .leading, spacing: 0) {
                    Text(song.trackName)
                        .font(.caption)
                        .lineLimit(1)
                    Text(song.artistName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Status / empty

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "music.note.list")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text("No songs yet")
                .font(.caption)
                .fontWeight(.semibold)
            Text("Search above or play something on your iPhone.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .listRowBackground(Color.clear)
    }

    private func statusRow(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(text).font(.caption2)
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Phone → Watch persistence

    private func persistFromPhone(_ songs: [Song]) {
        guard !songs.isEmpty else { return }

        let existing = (try? modelContext.fetch(
            FetchDescriptor<CachedSong>(
                predicate: #Predicate { $0.lastPlayedAt != nil }
            )
        )) ?? []
        for row in existing {
            row.lastPlayedAt = nil
        }

        let now = Date()
        for (offset, song) in songs.enumerated() {
            let trackId = song.trackId
            let descriptor = FetchDescriptor<CachedSong>(
                predicate: #Predicate { $0.trackId == trackId }
            )
            if let row = try? modelContext.fetch(descriptor).first {
                row.lastPlayedAt = now.addingTimeInterval(TimeInterval(-offset))
            } else {
                let cached = CachedSong(from: song)
                cached.lastPlayedAt = now.addingTimeInterval(TimeInterval(-offset))
                modelContext.insert(cached)
            }
        }
        try? modelContext.save()
    }
}
