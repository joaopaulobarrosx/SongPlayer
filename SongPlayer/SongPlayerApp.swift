import SwiftUI
import SwiftData

@main
struct SongPlayerApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            CachedSong.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    init() {
        // Activate the WatchConnectivity session early so the paired Apple
        // Watch can start receiving Recently Played updates immediately.
        _ = iOSConnectivityService.shared

        // Mark every song that starts playing (autoplay, next/previous, tap)
        // as recently played so the list stays in sync with actual playback.
        let container = sharedModelContainer
        AudioPlayerService.shared.onSongStarted = { song in
            let context = ModelContext(container)
            let trackId = song.trackId
            let descriptor = FetchDescriptor<CachedSong>(
                predicate: #Predicate { $0.trackId == trackId }
            )
            if let existing = try? context.fetch(descriptor).first {
                existing.lastPlayedAt = Date()
            } else {
                let cached = CachedSong(from: song)
                cached.lastPlayedAt = Date()
                context.insert(cached)
            }
            try? context.save()
            iOSConnectivityService.shared.publishRecentlyPlayed(from: context)
        }
    }

    var body: some Scene {
        WindowGroup {
            SplashView()
        }
        .modelContainer(sharedModelContainer)
    }
}
