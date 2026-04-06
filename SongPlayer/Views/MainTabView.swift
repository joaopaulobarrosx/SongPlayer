import SwiftUI

struct MainTabView: View {
    @State private var audioPlayer = AudioPlayerService()

    var body: some View {
        SongsView(audioPlayer: audioPlayer)
    }
}
