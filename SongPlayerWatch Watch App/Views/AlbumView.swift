import SwiftUI
import SwiftData
import SongPlayerCore

struct AlbumView: View {
    let collectionId: Int
    @Bindable var audioPlayer: WatchAudioPlayerService
    @Environment(\.modelContext) private var modelContext

    @State private var viewModel = AlbumViewModel()
    @State private var songsViewModel = SongsViewModel()
    @State private var navigateToSong: Song?

    var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                ProgressView()
            case .offline:
                VStack(spacing: 4) {
                    Image(systemName: "wifi.slash")
                    Text("No internet").font(.caption2)
                }
                .foregroundStyle(.secondary)
            case .error(let message):
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
            case .loaded:
                content
            }
        }
        .navigationTitle(viewModel.songs.first?.collectionName ?? "Album")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadAlbum(collectionId: collectionId)
        }
        .navigationDestination(item: $navigateToSong) { song in
            PlayerView(audioPlayer: audioPlayer, fallbackSong: song)
        }
    }

    private var content: some View {
        List {
            if let first = viewModel.songs.first {
                Section {
                    VStack(spacing: 6) {
                        CachedAsyncImage(url: URL(string: first.artworkUrlLarge ?? "")) { image in
                            image.resizable().aspectRatio(contentMode: .fit)
                        } placeholder: {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.quaternary)
                                .overlay { Image(systemName: "music.note") }
                        }
                        .frame(width: 70, height: 70)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                        Text(first.collectionName ?? "")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                        Text(first.artistName)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                }
            }

            Section {
                ForEach(viewModel.songs) { song in
                    Button {
                        let index = viewModel.songs.firstIndex(where: { $0.id == song.id }) ?? 0
                        audioPlayer.play(song: song, playlist: viewModel.songs, index: index)
                        songsViewModel.markAsPlayed(song: song, modelContext: modelContext)
                        songsViewModel.cacheSongs(viewModel.songs, modelContext: modelContext)
                        navigateToSong = song
                    } label: {
                        HStack(spacing: 8) {
                            CachedAsyncImage(url: URL(string: song.artworkUrl100 ?? "")) { image in
                                image.resizable().aspectRatio(contentMode: .fill)
                            } placeholder: {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(.quaternary)
                                    .overlay { Image(systemName: "music.note").font(.caption2) }
                            }
                            .frame(width: 30, height: 30)
                            .clipShape(RoundedRectangle(cornerRadius: 4))

                            VStack(alignment: .leading, spacing: 0) {
                                Text(song.trackName)
                                    .font(.caption2)
                                    .lineLimit(1)
                                Text(song.artistName)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
