import Foundation
import Observation
import WatchConnectivity
import SongPlayerCore

/// Watch-side receiver for Recently Played updates pushed from the iPhone.
/// Exposes the most recent snapshot as an `@Observable` property so the
/// HomeView can react and persist into its own SwiftData store.
@MainActor
@Observable
final class WatchConnectivityService: NSObject {
    /// Latest snapshot received from the iPhone. Reset to empty on launch
    /// and replaced whenever the phone pushes a new context.
    var latestRecentlyPlayed: [Song] = []

    /// Monotonic counter bumped on every received payload. HomeView
    /// observes this so it can re-persist even if the song list happens
    /// to compare equal.
    private(set) var updateToken: Int = 0

    override init() {
        super.init()
        activate()
    }

    private func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        if session.activationState != .activated {
            session.activate()
        }
        // Pick up any context that may have arrived before we registered.
        applyContext(session.receivedApplicationContext)
    }

    fileprivate func applyContext(_ context: [String: Any]) {
        guard
            let data = context["recentlyPlayed"] as? Data,
            let songs = try? JSONDecoder().decode([Song].self, from: data)
        else { return }
        self.latestRecentlyPlayed = songs
        self.updateToken &+= 1
    }
}

extension WatchConnectivityService: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        // On activation, replay any existing context.
        let context = session.receivedApplicationContext
        Task { @MainActor in
            self.applyContext(context)
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        let context = applicationContext
        Task { @MainActor in
            self.applyContext(context)
        }
    }
}
