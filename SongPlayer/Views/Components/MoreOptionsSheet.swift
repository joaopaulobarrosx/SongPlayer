import SwiftUI

struct MoreOptionsSheet: View {
    let song: Song
    var onViewAlbum: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Song info
            HStack(spacing: 12) {
                AsyncImage(url: URL(string: song.artworkUrl100 ?? "")) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    default:
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.quaternary)
                            .overlay {
                                Image(systemName: "music.note")
                                    .foregroundStyle(.secondary)
                            }
                    }
                }
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(song.trackName)
                        .font(.headline)
                        .lineLimit(1)
                    Text(song.artistName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding()

            Divider()

            // Actions
            if song.collectionId != nil {
                Button {
                    onViewAlbum()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "music.note.list")
                            .frame(width: 24)
                        Text("View album")
                        Spacer()
                    }
                    .padding()
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .presentationDragIndicator(.visible)
    }
}
