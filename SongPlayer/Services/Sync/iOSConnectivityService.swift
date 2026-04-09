import Foundation
import SwiftData
import WatchConnectivity

/// iPhone-side push of the Recently Played list to the paired Apple Watch.
/// Uses `updateApplicationContext` so only the latest snapshot is delivered
/// (perfect for a "most recent N" use case — older pushes are coalesced).
@MainActor
final class iOSConnectivityService: NSObject {
    static let shared = iOSConnectivityService()

    /// Latest encoded payload waiting to be delivered. We keep only the most
    /// recent one because `updateApplicationContext` itself coalesces.
    private var pendingPayload: [String: Any]?

    private override init() {
        super.init()
        activate()
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        if session.activationState != .activated {
            session.activate()
        }
    }

    /// Fetches the top 20 recently played songs from SwiftData and sends them
    /// to the Watch as a single encoded blob in application context.
    func publishRecentlyPlayed(from modelContext: ModelContext) {
        let descriptor = FetchDescriptor<CachedSong>(
            predicate: #Predicate { $0.lastPlayedAt != nil },
            sortBy: [SortDescriptor(\.lastPlayedAt, order: .reverse)]
        )
        guard let cached = try? modelContext.fetch(descriptor) else { return }
        let songs = cached.prefix(20).map { $0.toSong() }

        guard let data = try? JSONEncoder().encode(Array(songs)) else { return }

        pendingPayload = ["recentlyPlayed": data]
        flush()
    }

    /// Delivers the pending payload if the session is active. Otherwise it
    /// stays queued until `activationDidCompleteWith` fires.
    private func flush() {
        guard let payload = pendingPayload else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }
        do {
            try session.updateApplicationContext(payload)
            pendingPayload = nil
        } catch {
            // Silently ignore — context sync is best-effort. Keep the payload
            // queued so the next successful flush can retry.
        }
    }
}

extension iOSConnectivityService: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        guard activationState == .activated else { return }
        Task { @MainActor in
            self.flush()
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        // Re-activate on the default session so we can pair with a new watch.
        WCSession.default.activate()
    }
}
