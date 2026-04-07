import SwiftUI
import SwiftData

struct SongsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = SongsViewModel()
    @Bindable var audioPlayer: AudioPlayerService
    @Binding var pendingAlbumId: Int?
    @State private var moreSheetSong: Song?
    @State private var navigateToAlbum: Int?
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        NavigationStack {
            List {
                searchBarSection

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
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle("Songs")
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
            .safeAreaInset(edge: .bottom) {
                MiniPlayerView(audioPlayer: audioPlayer)
            }
            .navigationDestination(item: $navigateToAlbum) { collectionId in
                AlbumView(collectionId: collectionId, audioPlayer: audioPlayer)
            }
            .onChange(of: pendingAlbumId) { _, newValue in
                if let id = newValue {
                    navigateToAlbum = id
                    pendingAlbumId = nil
                }
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

    private var searchBarSection: some View {
        Section {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search", text: $viewModel.searchText)
                    .textFieldStyle(.plain)
                    .submitLabel(.search)
                    .focused($isSearchFocused)
                    .onSubmit {
                        viewModel.searchSongs()
                    }
                if !viewModel.searchText.isEmpty {
                    Button {
                        viewModel.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
        }
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
    }

    private var recentlyPlayedSection: some View {
        Section {
            ForEach(viewModel.recentlyPlayed) { song in
                songRow(song: song, playlist: viewModel.recentlyPlayed)
            }
            .onDelete { offsets in
                for index in offsets {
                    let song = viewModel.recentlyPlayed[index]
                    viewModel.removeRecentlyPlayed(song: song, modelContext: modelContext)
                }
            }
        }
    }

    private var searchResultsSection: some View {
        Section {
            ForEach(viewModel.songs) { song in
                songRow(song: song, playlist: viewModel.songs)
                    .onAppear {
                        viewModel.loadMoreIfNeeded(currentSong: song)
                    }
            }
        }
    }

    private func songRow(song: Song, playlist: [Song]) -> some View {
        let isCurrent = audioPlayer.currentSong?.id == song.id && audioPlayer.state != .idle
        let isPlaying = isCurrent && audioPlayer.state == .playing

        return SongRowView(
            song: song,
            isPlaying: isPlaying,
            isCurrentSong: isCurrent
        ) {
            moreSheetSong = song
        }
        .onTapGesture {
            playSong(song, from: playlist)
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
        isSearchFocused = false
        let index = playlist.firstIndex(where: { $0.id == song.id }) ?? 0
        audioPlayer.play(song: song, playlist: playlist, index: index)
        viewModel.markAsPlayed(song: song, modelContext: modelContext)
        viewModel.cacheSongs(playlist, modelContext: modelContext)
    }
}
