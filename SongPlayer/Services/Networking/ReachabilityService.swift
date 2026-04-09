import Foundation

/// Lightweight reachability probe. Every 20 seconds it fires a tiny HEAD
/// request against a reliable endpoint and flips `isOnline` accordingly.
/// Using an actual network probe (instead of just `NWPathMonitor`) catches
/// "connected to Wi-Fi but no internet" scenarios too.
@MainActor
@Observable
final class ReachabilityService {
    static let shared = ReachabilityService()

    private(set) var isOnline: Bool = true

    private var timer: Timer?
    private let probeURL = URL(string: "https://www.apple.com/library/test/success.html")!
    private let interval: TimeInterval = 5

    private init() {
        start()
    }

    func start() {
        Task { await check() }
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.check() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// One-shot probe, also exposed so the UI can trigger an immediate
    /// re-check (e.g. when the banner appears).
    func check() async {
        var request = URLRequest(url: probeURL)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 5
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            let ok = (response as? HTTPURLResponse)?.statusCode ?? 0
            isOnline = (200..<400).contains(ok)
        } catch {
            isOnline = false
        }
    }
}
