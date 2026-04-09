import SwiftUI
import SongPlayerCore

struct RootView: View {
    @Bindable var audioPlayer: WatchAudioPlayerService
    @Bindable var connectivity: WatchConnectivityService
    @State private var showSplash = true

    var body: some View {
        ZStack {
            if showSplash {
                SplashView {
                    withAnimation(.easeOut(duration: 0.25)) {
                        showSplash = false
                    }
                }
                .transition(.opacity)
            } else {
                HomeView(audioPlayer: audioPlayer, connectivity: connectivity)
                    .transition(.opacity)
            }
        }
    }
}
