import SwiftUI

struct MainTabView: View {
    @State private var audioPlayer = AudioPlayerService()
    @State private var showFullPlayer = false

    var body: some View {
        SongsView(audioPlayer: audioPlayer)
            .fullScreenCover(isPresented: $showFullPlayer) {
                NavigationStack {
                    PlayerView(
                        song: audioPlayer.currentSong ?? Song.placeholder,
                        audioPlayer: audioPlayer
                    )
                }
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
