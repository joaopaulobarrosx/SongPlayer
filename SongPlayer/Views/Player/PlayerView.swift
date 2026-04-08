import SwiftUI

struct PlayerView: View {
    let song: Song
    @Bindable var audioPlayer: AudioPlayerService
    var onDismiss: (() -> Void)? = nil
    var onViewAlbum: ((Int) -> Void)?
    var networkService: NetworkServiceProtocol = NetworkService()

    @Environment(\.dismiss) private var environmentDismiss
    @State private var showMoreSheet = false
    @State private var albumHasTracks = false
    @State private var isDragging = false
    @State private var dragProgress: Double = 0
    @Binding var dragOffset: CGFloat
    @State private var isDismissGesture: Bool? = nil

    private func dismissPlayer() {
        if let onDismiss {
            onDismiss()
        } else {
            environmentDismiss()
        }
    }

    private var activeSong: Song {
        audioPlayer.currentSong ?? song
    }

    var body: some View {
        VStack(spacing: 0) {
            artworkView

            Spacer()
                .frame(height: 56)

            songInfoView

            Spacer()
                .frame(height: 28)

            timelineView

            Spacer()
                .frame(height: 44)

            controlsView

            Spacer()
                .frame(height: 40)
        }
        .padding(.horizontal, 24)
        .simultaneousGesture(
            DragGesture(minimumDistance: 30, coordinateSpace: .global)
                .onChanged { value in
                    let t = value.translation
                    // Determine gesture direction on first movement
                    if isDismissGesture == nil {
                        let isDownward = t.height > 0
                        let isPrimarilyVertical = abs(t.height) > abs(t.width)
                        isDismissGesture = isDownward && isPrimarilyVertical
                    }
                    guard isDismissGesture == true else { return }
                    let vertical = t.height
                    dragOffset = vertical * (1 - min(vertical / 600, 0.5))
                }
                .onEnded { value in
                    defer { isDismissGesture = nil }
                    guard isDismissGesture == true else { return }
                    let velocity = value.velocity.height
                    let translation = value.translation.height
                    if translation > 120 || velocity > 800 {
                        withAnimation(.easeOut(duration: 0.25)) {
                            // Large enough to slide off any device; avoids the
                            // deprecated UIScreen.main lookup.
                            dragOffset = 2000
                        }
                        dismissPlayer()
                    } else {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            dragOffset = 0
                        }
                    }
                }
        )
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismissPlayer()
                } label: {
                    Image(systemName: "chevron.left")
                        .fontWeight(.semibold)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            ToolbarItem(placement: .principal) {
                Text(activeSong.collectionName ?? "")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    albumHasTracks = false
                    showMoreSheet = true
                    if let collectionId = activeSong.collectionId {
                        Task {
                            do {
                                let response = try await networkService.lookupAlbum(collectionId: collectionId)
                                albumHasTracks = response.results.contains { $0.trackTimeMillis != nil }
                            } catch {
                                albumHasTracks = false
                            }
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .fontWeight(.bold)
                }
            }
        }
        .sheet(isPresented: $showMoreSheet) {
            MoreOptionsSheet(song: activeSong) {
                showMoreSheet = false
                if albumHasTracks, let collectionId = activeSong.collectionId {
                    onViewAlbum?(collectionId)
                }
            }
            .presentationDetents([.height(180)])
        }
    }

    // MARK: - Artwork

    private var artworkView: some View {
        GeometryReader { geo in
            CachedAsyncImage(url: URL(string: activeSong.artworkUrlLarge ?? "")) { image in
                image.resizable().aspectRatio(contentMode: .fit)
            } placeholder: {
                artworkPlaceholder
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
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                MarqueeText(
                    text: activeSong.trackName,
                    font: .system(size: 32),
                    fontWeight: .bold,
                    color: .white
                )
                Text(activeSong.artistName)
                    .font(.body)
                    .foregroundStyle(Color.white.opacity(0.6))
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
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24)
                    .foregroundStyle(.white)
            }
            .accessibilityLabel(audioPlayer.autoPlayEnabled ? "Auto-play on" : "Auto-play off")
        }
    }

    // MARK: - Timeline

    private var displayProgress: Double {
        isDragging ? dragProgress : audioPlayer.progress
    }

    private var timelineView: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                let trackWidth = geo.size.width
                let knobSize: CGFloat = 24
                let trackHeight: CGFloat = 8
                let filledWidth = max(0, min(trackWidth, trackWidth * displayProgress))
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.25))
                        .frame(height: trackHeight)
                    Capsule()
                        .fill(Color.white)
                        .frame(width: filledWidth, height: trackHeight)
                    Circle()
                        .fill(Color.white)
                        .frame(width: knobSize, height: knobSize)
                        .offset(x: filledWidth - knobSize / 2)
                }
                .frame(height: knobSize)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isDragging = true
                            dragProgress = max(0, min(1, value.location.x / trackWidth))
                        }
                        .onEnded { value in
                            let pct = max(0, min(1, value.location.x / trackWidth))
                            dragProgress = pct
                            audioPlayer.seek(to: pct)
                            isDragging = false
                        }
                )
            }
            .frame(height: 24)
            .padding(.top, 4)

            HStack {
                Text(formatTime(displayProgress * audioPlayer.duration))
                    .font(.system(size: 14))
                    .foregroundStyle(Color.white.opacity(0.6))
                    .monospacedDigit()
                Spacer()
                Text("-\(formatTime(audioPlayer.duration - displayProgress * audioPlayer.duration))")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.white.opacity(0.6))
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
                Image(systemName: "backward.end.alt.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.white)
            }
            .accessibilityLabel("Previous")

            Button {
                audioPlayer.togglePlayPause()
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.20))
                        .overlay(
                            Circle()
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.6),
                                            Color.white.opacity(0.05),
                                            Color.white.opacity(0.6)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.5
                                )
                        )
                        .frame(width: 72, height: 72)
                    Image(systemName: audioPlayer.state == .playing ? "pause.fill" : "play.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 25, height: 28.5)
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(audioPlayer.state == .playing ? "Pause" : "Play")

            Button {
                audioPlayer.playNext()
            } label: {
                Image(systemName: "forward.end.alt.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.white)
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
