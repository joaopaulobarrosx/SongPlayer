import SwiftUI

struct MainTabView: View {
    @State private var audioPlayer = AudioPlayerService()
    @State private var showFullPlayer = false
    @State private var playerDragOffset: CGFloat = 0
    @State private var pendingAlbumId: Int?
    @State private var reachability = ReachabilityService.shared

    var body: some View {
        SongsView(audioPlayer: audioPlayer, pendingAlbumId: $pendingAlbumId)
            .environment(reachability)
            .fullScreenCover(isPresented: $showFullPlayer, onDismiss: {
                playerDragOffset = 0
            }) {
                PlayerNavigationContainer(
                    audioPlayer: audioPlayer,
                    onDismiss: { showFullPlayer = false },
                    playerDragOffset: $playerDragOffset
                )
                .offset(y: playerDragOffset)
            }
            .environment(\.openFullPlayer, { showFullPlayer = true })
    }
}

// MARK: - Player navigation container

private struct PlayerNavigationContainer: View {
    @Bindable var audioPlayer: AudioPlayerService
    var onDismiss: () -> Void
    @Binding var playerDragOffset: CGFloat
    @State private var albumDestination: Int?

    var body: some View {
        NavigationStack {
            PlayerView(
                song: audioPlayer.currentSong ?? Song.placeholder,
                audioPlayer: audioPlayer,
                onDismiss: onDismiss,
                onViewAlbum: { albumDestination = $0 },
                dragOffset: $playerDragOffset
            )
            .navigationDestination(item: $albumDestination) { id in
                AlbumView(collectionId: id, audioPlayer: audioPlayer)
            }
        }
        .environment(\.openFullPlayer, { albumDestination = nil })
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
