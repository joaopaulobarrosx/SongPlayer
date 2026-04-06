import SwiftUI

struct PlayerView: View {
    let song: Song
    @Bindable var audioPlayer: AudioPlayerService
    var onViewAlbum: ((Int) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var showMoreSheet = false
    @State private var isDragging = false
    @State private var dragProgress: Double = 0

    private var activeSong: Song {
        audioPlayer.currentSong ?? song
    }

    var body: some View {
        VStack(spacing: 0) {
            artworkView

            Spacer()
                .frame(height: 32)

            songInfoView

            Spacer()
                .frame(height: 20)

            timelineView

            Spacer()
                .frame(height: 28)

            controlsView

            Spacer()
                .frame(height: 40)
        }
        .padding(.horizontal, 24)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .fontWeight(.semibold)
                }
            }
            ToolbarItem(placement: .principal) {
                Text(activeSong.collectionName ?? "")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { showMoreSheet = true } label: {
                    Image(systemName: "ellipsis")
                        .fontWeight(.bold)
                }
            }
        }
        .sheet(isPresented: $showMoreSheet) {
            MoreOptionsSheet(song: activeSong) {
                showMoreSheet = false
                if let collectionId = activeSong.collectionId {
                    dismiss()
                    onViewAlbum?(collectionId)
                }
            }
            .presentationDetents([.height(180)])
        }
    }

    // MARK: - Artwork

    private var artworkView: some View {
        GeometryReader { geo in
            AsyncImage(url: URL(string: activeSong.artworkUrlLarge ?? "")) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fit)
                case .failure, .empty:
                    artworkPlaceholder
                @unknown default:
                    artworkPlaceholder
                }
            }
            .frame(width: geo.size.width, height: geo.size.width)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(radius: 20)
        }
        .aspectRatio(1, contentMode: .fit)
        .padding(.top, 8)
        .accessibilityLabel("Album artwork")
    }

    // MARK: - Song Info

    private var songInfoView: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                MarqueeText(
                    text: activeSong.trackName,
                    font: .title2,
                    fontWeight: .bold,
                    color: Color(.label)
                )
                Text(activeSong.artistName)
                    .font(.body)
                    .foregroundStyle(Color(.secondaryLabel))
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            // Auto-play toggle — white always, icon reflects state
            Button {
                audioPlayer.autoPlayEnabled.toggle()
            } label: {
                Image(systemName: audioPlayer.autoPlayEnabled
                      ? "repeat"
                      : "minus.arrow.trianglehead.counterclockwise")
                    .font(.title3)
                    .foregroundStyle(.white)
            }
            .accessibilityLabel(audioPlayer.autoPlayEnabled ? "Auto-play on" : "Auto-play off")
        }
    }

    // MARK: - Timeline

    private var timelineView: some View {
        VStack(spacing: 6) {
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
            .tint(Color(.label))

            HStack {
                Text(formatTime(isDragging ? dragProgress * audioPlayer.duration : audioPlayer.currentTime))
                    .font(.caption2)
                    .foregroundStyle(Color(.secondaryLabel))
                    .monospacedDigit()
                Spacer()
                Text("-\(formatTime(audioPlayer.duration - (isDragging ? dragProgress * audioPlayer.duration : audioPlayer.currentTime)))")
                    .font(.caption2)
                    .foregroundStyle(Color(.secondaryLabel))
                    .monospacedDigit()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Song progress: \(formatTime(audioPlayer.currentTime)) of \(formatTime(audioPlayer.duration))")
    }

    // MARK: - Controls

    private var controlsView: some View {
        HStack(spacing: 40) {
            Button {
                audioPlayer.playPrevious()
            } label: {
                Image(systemName: "backward.fill")
                    .font(.title2)
                    .foregroundStyle(Color(.label))
            }
            .accessibilityLabel("Previous")

            Button {
                audioPlayer.togglePlayPause()
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 72, height: 72)
                    Image(systemName: audioPlayer.state == .playing ? "pause.fill" : "play.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(Color(.label))
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(audioPlayer.state == .playing ? "Pause" : "Play")

            Button {
                audioPlayer.playNext()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.title2)
                    .foregroundStyle(Color(.label))
            }
            .accessibilityLabel("Next")
        }
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

    private func formatTime(_ seconds: TimeInterval) -> String {
        guard !seconds.isNaN && seconds >= 0 else { return "0:00" }
        let totalSeconds = Int(seconds)
        return String(format: "%d:%02d", totalSeconds / 60, totalSeconds % 60)
    }
}
