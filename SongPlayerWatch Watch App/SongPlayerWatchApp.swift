import SwiftUI
import SwiftData
import SongPlayerCore

@main
struct SongPlayerWatchApp: App {
    let sharedModelContainer: ModelContainer = {
        let schema = Schema([CachedSong.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    @State private var audioPlayer = WatchAudioPlayerService()
    @State private var connectivity = WatchConnectivityService()

    var body: some Scene {
        WindowGroup {
            RootView(audioPlayer: audioPlayer, connectivity: connectivity)
                .preferredColorScheme(.dark)
        }
        .modelContainer(sharedModelContainer)
    }
}
