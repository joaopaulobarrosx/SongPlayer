import SwiftUI
import SwiftData

struct AlbumView: View {
    let collectionId: Int
    @Bindable var audioPlayer: AudioPlayerService
    @Environment(\.modelContext) private var modelContext

    @State private var viewModel = AlbumViewModel()
    @State private var selectedSong: Song?
    @State private var playerDragOffset: CGFloat = 0

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
                AsyncImage(url: URL(string: firstSong.artworkUrlLarge ?? "")) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    default:
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.quaternary)
                            .overlay {
                                Image(systemName: "music.note")
                                    .font(.largeTitle)
                                    .foregroundStyle(.secondary)
                            }
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
                HStack(spacing: 12) {
                    AsyncImage(url: URL(string: song.artworkUrl100 ?? "")) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        default:
                            RoundedRectangle(cornerRadius: 4)
                                .fill(.quaternary)
                                .overlay {
                                    Image(systemName: "music.note")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                        }
                    }
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(song.trackName)
                            .font(.body)
                            .lineLimit(1)
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
                    selectedSong = song
                }
                .accessibilityLabel("\(song.trackName) by \(song.artistName)")

                if song.id != viewModel.songs.last?.id {
                    Divider()
                        .padding(.leading, 68)
                }
            }
        }
    }
}
