import SwiftUI

struct MiniPlayerView: View {
    @Bindable var audioPlayer: AudioPlayerService
    @Environment(\.openFullPlayer) private var openFullPlayer

    var body: some View {
        if let song = audioPlayer.currentSong, audioPlayer.state != .idle {
            VStack(spacing: 0) {
                GeometryReader { geo in
                    Rectangle()
                        .fill(Color.green)
                        .frame(width: geo.size.width * audioPlayer.progress)
                }
                .frame(height: 2)

                HStack(spacing: 12) {
                    AsyncImage(url: URL(string: song.artworkUrl100 ?? "")) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        default:
                            RoundedRectangle(cornerRadius: 6)
                                .fill(.quaternary)
                                .overlay {
                                    Image(systemName: "music.note")
                                        .foregroundStyle(.secondary)
                                }
                        }
                    }
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(song.trackName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .lineLimit(1)
                        Text(song.artistName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Button {
                        audioPlayer.togglePlayPause()
                    } label: {
                        Image(systemName: audioPlayer.state == .playing ? "pause.fill" : "play.fill")
                            .font(.title3)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(audioPlayer.state == .playing ? "Pause" : "Play")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.15), radius: 8, y: -2)
            .padding(.horizontal, 8)
            .contentShape(Rectangle())
            .onTapGesture {
                openFullPlayer()
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Now playing: \(song.trackName) by \(song.artistName)")
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("Tap to open player")
        }
    }
}
