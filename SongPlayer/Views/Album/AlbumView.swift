import SwiftUI
import SwiftData

struct AlbumView: View {
    let collectionId: Int
    @Bindable var audioPlayer: AudioPlayerService
    @Environment(\.modelContext) private var modelContext

    @State private var viewModel = AlbumViewModel()
    @State private var songsViewModel = SongsViewModel()
    @State private var selectedSong: Song?
    @State private var playerDragOffset: CGFloat = 0
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                ProgressView()
            case .error(let message):
                ContentUnavailableView(
                    "Failed to Load Album",
                    systemImage: "exclamationmark.triangle",
                    description: Text(message)
                )
            case .offline:
                ContentUnavailableView(
                    "No internet connection",
                    systemImage: "wifi.slash",
                    description: Text("Connect to the internet to load this album.")
                )
            case .loaded:
                albumContent
            }
        }
        .safeAreaInset(edge: .bottom) {
            MiniPlayerView(audioPlayer: audioPlayer)
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadAlbum(collectionId: collectionId)
        }
        .navigationDestination(item: $selectedSong) { song in
            PlayerView(song: song, audioPlayer: audioPlayer, dragOffset: $playerDragOffset)
                .offset(y: playerDragOffset)
        }
    }

    private var albumContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                albumHeader
                songsList
            }
        }
    }

    private var albumHeader: some View {
        VStack(spacing: 12) {
            if let firstSong = viewModel.songs.first {
                CachedAsyncImage(url: URL(string: firstSong.artworkUrlLarge ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.quaternary)
                        .overlay {
                            Image(systemName: "music.note")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                        }
                }
                .frame(width: 180, height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(radius: 10)

                Text(firstSong.collectionName ?? "Album")
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text(firstSong.artistName)
                    .font(.subheadline)
                    .foregroundStyle(.white)
            }
        }
        .padding(.top, 16)
        .padding(.horizontal)
    }

    private var songsList: some View {
        LazyVStack(spacing: 0) {
            ForEach(viewModel.songs) { song in
                let isCurrent = audioPlayer.currentSong?.id == song.id && audioPlayer.state != .idle
                let isPlaying = isCurrent && audioPlayer.state == .playing
                HStack(spacing: 12) {
                    CachedAsyncImage(url: URL(string: song.artworkUrl100 ?? "")) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.quaternary)
                            .overlay {
                                Image(systemName: "music.note")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                    }
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            if isCurrent {
                                NowPlayingIcon(isPlaying: isPlaying)
                            }
                            Text(song.trackName)
                                .font(.body)
                                .lineLimit(1)
                                .foregroundStyle(isCurrent ? .green : .primary)
                        }
                        Text(song.artistName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
                .onTapGesture {
                    let index = viewModel.songs.firstIndex(where: { $0.id == song.id }) ?? 0
                    audioPlayer.play(song: song, playlist: viewModel.songs, index: index)
                    songsViewModel.markAsPlayed(song: song, modelContext: modelContext)
                }
                .accessibilityLabel("\(song.trackName) by \(song.artistName)")

            }
        }
    }
}
