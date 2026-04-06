import SwiftUI

struct PlayerView: View {
    let song: Song
    @Bindable var audioPlayer: AudioPlayerService
    var onViewAlbum: ((Int) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var showMoreSheet = false
    @State private var isDragging = false
    @State private var dragProgress: Double = 0

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            artworkView

            Spacer()
                .frame(height: 32)

            songInfoView

            Spacer()
                .frame(height: 24)

            timelineView

            Spacer()
                .frame(height: 24)

            controlsView

            Spacer()
        }
        .padding(.horizontal, 32)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(song.collectionName ?? "")
                    .font(.caption)
                    .lineLimit(1)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showMoreSheet = true
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showMoreSheet) {
            MoreOptionsSheet(song: audioPlayer.currentSong ?? song) {
                showMoreSheet = false
                if let collectionId = (audioPlayer.currentSong ?? song).collectionId {
                    dismiss()
                    onViewAlbum?(collectionId)
                }
            }
            .presentationDetents([.height(180)])
        }
    }

    // MARK: - Subviews

    private var artworkView: some View {
        AsyncImage(url: URL(string: (audioPlayer.currentSong ?? song).artworkUrlLarge ?? "")) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            case .failure:
                artworkPlaceholder
            case .empty:
                artworkPlaceholder
                    .overlay(ProgressView().tint(.white))
            @unknown default:
                artworkPlaceholder
            }
        }
        .frame(maxWidth: 300, maxHeight: 300)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 20)
        .accessibilityLabel("Album artwork")
    }

    private var songInfoView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text((audioPlayer.currentSong ?? song).trackName)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                Text((audioPlayer.currentSong ?? song).artistName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
        }
    }

    private var timelineView: some View {
        VStack(spacing: 4) {
            Slider(
                value: Binding(
                    get: { isDragging ? dragProgress : audioPlayer.progress },
                    set: { newValue in
                        isDragging = true
                        dragProgress = newValue
                    }
                ),
                in: 0...1,
                onEditingChanged: { editing in
                    if !editing {
                        audioPlayer.seek(to: dragProgress)
                        isDragging = false
                    }
                }
            )
            .tint(.primary)

            HStack {
                Text(formatTime(isDragging ? dragProgress * audioPlayer.duration : audioPlayer.currentTime))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                Spacer()
                Text("-\(formatTime(audioPlayer.duration - (isDragging ? dragProgress * audioPlayer.duration : audioPlayer.currentTime)))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Song progress: \(formatTime(audioPlayer.currentTime)) of \(formatTime(audioPlayer.duration))")
    }

    private var controlsView: some View {
        HStack(spacing: 48) {
            Button {
                audioPlayer.playPrevious()
            } label: {
                Image(systemName: "backward.fill")
                    .font(.title2)
            }
            .accessibilityLabel("Previous")

            Button {
                audioPlayer.togglePlayPause()
            } label: {
                Image(systemName: audioPlayer.state == .playing ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 56))
            }
            .accessibilityLabel(audioPlayer.state == .playing ? "Pause" : "Play")

            Button {
                audioPlayer.playNext()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.title2)
            }
            .accessibilityLabel("Next")
        }
        .foregroundStyle(.primary)
    }

    private var artworkPlaceholder: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(.quaternary)
            .overlay {
                Image(systemName: "music.note")
                    .font(.system(size: 60))
                    .foregroundStyle(.secondary)
            }
    }

    // MARK: - Helpers

    private func formatTime(_ seconds: TimeInterval) -> String {
        guard !seconds.isNaN && seconds >= 0 else { return "0:00" }
        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}
