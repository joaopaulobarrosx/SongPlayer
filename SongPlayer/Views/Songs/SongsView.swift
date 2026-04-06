import SwiftUI
import SwiftData

struct SongsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = SongsViewModel()
    @Bindable var audioPlayer: AudioPlayerService
    @State private var selectedSong: Song?
    @State private var showMoreSheet = false
    @State private var moreSheetSong: Song?
    @State private var navigateToAlbum: Int?

    var body: some View {
        NavigationStack {
            List {
                if viewModel.searchText.isEmpty && !viewModel.recentlyPlayed.isEmpty {
                    recentlyPlayedSection
                }

                if !viewModel.songs.isEmpty {
                    searchResultsSection
                }

                if case .loading = viewModel.state {
                    loadingRow
                }

                if case .error(let message) = viewModel.state {
                    errorRow(message)
                }
            }
            .listStyle(.plain)
            .navigationTitle("Songs")
            .searchable(text: $viewModel.searchText, prompt: "Search")
            .onSubmit(of: .search) {
                viewModel.searchSongs()
            }
            .onChange(of: viewModel.searchText) {
                if viewModel.searchText.isEmpty {
                    viewModel.searchSongs()
                }
            }
            .refreshable {
                viewModel.searchSongs()
                try? await Task.sleep(for: .milliseconds(500))
            }
            .overlay {
                if viewModel.songs.isEmpty && viewModel.recentlyPlayed.isEmpty && viewModel.state == .idle {
                    ContentUnavailableView(
                        "Search for Songs",
                        systemImage: "music.note",
                        description: Text("Find your favorite songs on iTunes")
                    )
                }
                if viewModel.songs.isEmpty && viewModel.searchText.isEmpty == false,
                   case .loaded = viewModel.state {
                    ContentUnavailableView.search(text: viewModel.searchText)
                }
            }
            .navigationDestination(item: $selectedSong) { song in
                PlayerView(
                    song: song,
                    audioPlayer: audioPlayer,
                    onViewAlbum: { collectionId in
                        selectedSong = nil
                        Task {
                            try? await Task.sleep(for: .milliseconds(300))
                            navigateToAlbum = collectionId
                        }
                    }
                )
            }
            .navigationDestination(item: $navigateToAlbum) { collectionId in
                AlbumView(collectionId: collectionId, audioPlayer: audioPlayer)
            }
            .sheet(item: $moreSheetSong) { song in
                MoreOptionsSheet(song: song) {
                    moreSheetSong = nil
                    if let collectionId = song.collectionId {
                        navigateToAlbum = collectionId
                    }
                }
                .presentationDetents([.height(180)])
            }
        }
        .onAppear {
            viewModel.loadRecentlyPlayed(modelContext: modelContext)
        }
    }

    // MARK: - Sections

    private var recentlyPlayedSection: some View {
        Section {
            ForEach(viewModel.recentlyPlayed) { song in
                SongRowView(song: song) {
                    moreSheetSong = song
                }
                .onTapGesture {
                    playSong(song, from: viewModel.recentlyPlayed)
                }
            }
        } header: {
            Text("Recently Played")
                .font(.headline)
                .foregroundStyle(.primary)
                .textCase(nil)
        }
    }

    private var searchResultsSection: some View {
        Section {
            ForEach(viewModel.songs) { song in
                SongRowView(song: song) {
                    moreSheetSong = song
                }
                .onTapGesture {
                    playSong(song, from: viewModel.songs)
                }
                .onAppear {
                    viewModel.loadMoreIfNeeded(currentSong: song)
                }
            }
        }
    }

    private var loadingRow: some View {
        HStack {
            Spacer()
            ProgressView()
            Spacer()
        }
        .listRowSeparator(.hidden)
    }

    private func errorRow(_ message: String) -> some View {
        VStack(spacing: 8) {
            Text("Something went wrong")
                .font(.headline)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Retry") {
                viewModel.searchSongs()
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .listRowSeparator(.hidden)
    }

    // MARK: - Actions

    private func playSong(_ song: Song, from playlist: [Song]) {
        let index = playlist.firstIndex(where: { $0.id == song.id }) ?? 0
        audioPlayer.play(song: song, playlist: playlist, index: index)
        viewModel.markAsPlayed(song: song, modelContext: modelContext)
        viewModel.cacheSongs(playlist, modelContext: modelContext)
        selectedSong = song
    }
}
