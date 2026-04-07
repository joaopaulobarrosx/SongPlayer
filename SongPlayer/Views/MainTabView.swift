import SwiftUI

struct MainTabView: View {
    @State private var audioPlayer = AudioPlayerService()
    @State private var showFullPlayer = false
    @State private var playerDragOffset: CGFloat = 0
    @State private var pendingAlbumId: Int?

    var body: some View {
        SongsView(audioPlayer: audioPlayer, pendingAlbumId: $pendingAlbumId)
            .fullScreenCover(isPresented: $showFullPlayer, onDismiss: {
                playerDragOffset = 0
            }) {
                NavigationStack {
                    PlayerView(
                        song: audioPlayer.currentSong ?? Song.placeholder,
                        audioPlayer: audioPlayer,
                        onDismiss: { showFullPlayer = false },
                        onViewAlbum: { id in
                            showFullPlayer = false
                            pendingAlbumId = id
                        },
                        dragOffset: $playerDragOffset
                    )
                }
                .offset(y: playerDragOffset)
            }
            .environment(\.openFullPlayer, { showFullPlayer = true })
    }
}

// MARK: - Environment key for opening full player

private struct OpenFullPlayerKey: EnvironmentKey {
    nonisolated(unsafe) static let defaultValue: () -> Void = {}
}

extension EnvironmentValues {
    var openFullPlayer: () -> Void {
        get { self[OpenFullPlayerKey.self] }
        set { self[OpenFullPlayerKey.self] = newValue }
    }
}
