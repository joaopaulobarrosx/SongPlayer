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
    }

    var body: some Scene {
        WindowGroup {
            SplashView()
        }
        .modelContainer(sharedModelContainer)
    }
}
