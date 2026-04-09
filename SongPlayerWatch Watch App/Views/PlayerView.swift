import SwiftUI
import SongPlayerCore

/// Compact Watch player screen that matches the Figma: artwork, title+artist,
/// and three transport controls (prev / play-pause / next).
struct PlayerView: View {
    @Bindable var audioPlayer: WatchAudioPlayerService
    let fallbackSong: Song
    var onViewAlbum: ((Int) -> Void)? = nil

    @State private var showMore = false

    private var activeSong: Song {
        audioPlayer.currentSong ?? fallbackSong
    }

    var body: some View {
        VStack(spacing: 6) {
            CachedAsyncImage(url: URL(string: activeSong.artworkUrlLarge ?? "")) { image in
                image.resizable().aspectRatio(contentMode: .fit)
            } placeholder: {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.quaternary)
                    .overlay { Image(systemName: "music.note").font(.title) }
            }
            .frame(height: 80)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(spacing: 1) {
                Text(activeSong.trackName)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                Text(activeSong.artistName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            HStack(spacing: 18) {
                Button { audioPlayer.playPrevious() } label: {
                    Image(systemName: "backward.end.fill")
                        .font(.system(size: 18))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Previous")

                Button { audioPlayer.togglePlayPause() } label: {
                    Image(systemName: audioPlayer.state == .playing ? "pause.fill" : "play.fill")
                        .font(.system(size: 22))
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Color.white.opacity(0.15)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(audioPlayer.state == .playing ? "Pause" : "Play")

                Button { audioPlayer.playNext() } label: {
                    Image(systemName: "forward.end.fill")
                        .font(.system(size: 18))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Next")
            }
            .padding(.top, 2)
        }
        .padding(.horizontal, 4)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showMore = true
                } label: {
                    Image(systemName: "ellipsis")
                }
                .accessibilityLabel("More")
            }
        }
        .sheet(isPresented: $showMore) {
            MoreOptionsSheet(song: activeSong) {
                showMore = false
                if let id = activeSong.collectionId {
                    onViewAlbum?(id)
                }
            }
        }
    }
}

/// Minimal bottom sheet to match the iPhone "More options".
struct MoreOptionsSheet: View {
    let song: Song
    var onViewAlbum: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Text(song.trackName)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .lineLimit(2)

                if song.collectionId != nil {
                    Button {
                        onViewAlbum()
                    } label: {
                        Label("View album", systemImage: "music.note.list")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                }

                Button("Close") { dismiss() }
                    .font(.caption2)
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
    }
}
