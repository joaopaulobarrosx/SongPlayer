import SwiftUI

struct SongRowView: View {
    let song: Song
    var isPlaying: Bool = false
    var isCurrentSong: Bool = false
    var onMoreTapped: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: song.artworkUrl100 ?? "")) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    artworkPlaceholder
                case .empty:
                    artworkPlaceholder
                        .overlay(ProgressView().tint(.secondary))
                @unknown default:
                    artworkPlaceholder
                }
            }
            .frame(width: 48, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            if isCurrentSong {
                NowPlayingIcon(isPlaying: isPlaying)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(song.trackName)
                    .font(.body)
                    .lineLimit(1)
                    .foregroundStyle(isCurrentSong ? .green : .primary)
                Text(song.artistName)
                    .font(.caption)
                    .foregroundStyle(isCurrentSong ? .green.opacity(0.7) : .secondary)
                    .lineLimit(1)
            }

            Spacer()

            if let onMoreTapped {
                Button {
                    onMoreTapped()
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(song.trackName) by \(song.artistName)\(isCurrentSong ? ", now playing" : "")")
        .accessibilityAddTraits(.isButton)
    }

    private var artworkPlaceholder: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(.quaternary)
            .overlay {
                Image(systemName: "music.note")
                    .foregroundStyle(.secondary)
            }
    }
}
