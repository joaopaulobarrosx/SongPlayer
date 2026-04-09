import AVFoundation
import MediaPlayer

@MainActor
@Observable
final class AudioPlayerService {
    /// Shared instance so non-SwiftUI scenes (like CarPlay) can control the
    /// same player the phone UI uses.
    static let shared = AudioPlayerService()

    enum PlaybackState {
        case idle
        case loading
        case playing
        case paused
    }

    private(set) var state: PlaybackState = .idle
    private(set) var currentTime: TimeInterval = 0
    private(set) var duration: TimeInterval = 0
    private(set) var currentSong: Song?

    private var player: AVPlayer?
    private var timeObserver: Any?
    private var statusObservation: NSKeyValueObservation?
    private var didFinishObserver: NSObjectProtocol?
    private var isSeeking = false
    private var seekGuardTask: Task<Void, Never>?

    var progress: Double {
        guard duration > 0 else { return 0 }
        return currentTime / duration
    }

    var playlist: [Song] = []
    var currentIndex: Int = 0
    var autoPlayEnabled: Bool = true
    /// Called every time a song starts playing (tap, autoplay, next/previous).
    /// The UI layer hooks into this to update `lastPlayedAt` in SwiftData.
    var onSongStarted: ((Song) -> Void)?

    init() {
        configureAudioSession()
        setupRemoteCommandCenter()
    }

    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            // Audio session configuration failed
        }
    }

    // MARK: - Now Playing Info & Remote Commands

    private func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.togglePlayPause()
            }
            return .success
        }

        commandCenter.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.togglePlayPause()
            }
            return .success
        }

        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.playNext()
            }
            return .success
        }

        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.playPrevious()
            }
            return .success
        }

        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let positionEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            Task { @MainActor in
                guard let self, self.duration > 0 else { return }
                let progress = positionEvent.positionTime / self.duration
                self.seek(to: progress)
            }
            return .success
        }
    }

    private func updateNowPlayingInfo() {
        guard let song = currentSong else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }

        var info: [String: Any] = [
            MPMediaItemPropertyTitle: song.trackName,
            MPMediaItemPropertyArtist: song.artistName,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyPlaybackRate: state == .playing ? 1.0 : 0.0,
        ]

        if let albumName = song.collectionName {
            info[MPMediaItemPropertyAlbumTitle] = albumName
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        // CarPlay reads `playbackState` directly to flip its play/pause button.
        // Without this the button stays stale even when `nowPlayingInfo` is updated.
        switch state {
        case .playing: MPNowPlayingInfoCenter.default().playbackState = .playing
        case .paused:  MPNowPlayingInfoCenter.default().playbackState = .paused
        case .loading: MPNowPlayingInfoCenter.default().playbackState = .interrupted
        case .idle:    MPNowPlayingInfoCenter.default().playbackState = .stopped
        }

        // Load artwork: try cached file first, then the large (600x600) URL,
        // then fall back to the thumbnail (100x100). `artworkUrlLarge` is
        // synthesised by string replacement so it's never nil — but the file
        // doesn't always exist on the iTunes CDN, so we must actually fall
        // back on a failed download, not just on a nil URL. Without this,
        // CarPlay shows no artwork at all for those songs.
        let candidates = [song.artworkUrlLarge, song.artworkUrl100]
            .compactMap { $0 }
            .compactMap { URL(string: $0) }
        guard !candidates.isEmpty else { return }
        Task.detached {
            var image: UIImage?
            for url in candidates {
                var data: Data?
                if let cachedLocal = MediaCacheService.shared.localURL(for: url, kind: .image) {
                    data = try? Data(contentsOf: cachedLocal)
                }
                if data == nil {
                    data = try? await URLSession.shared.data(from: url).0
                }
                if let data, let loaded = UIImage(data: data) {
                    image = loaded
                    break
                }
            }
            guard let image else { return }
            let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
            await MainActor.run {
                var currentInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
                currentInfo[MPMediaItemPropertyArtwork] = artwork
                MPNowPlayingInfoCenter.default().nowPlayingInfo = currentInfo
            }
        }
    }

    // MARK: - Playback

    func play(song: Song, playlist: [Song]? = nil, index: Int = 0) {
        if let playlist {
            self.playlist = playlist
            self.currentIndex = index
        }

        guard let urlString = song.previewUrl, let remoteURL = URL(string: urlString) else { return }

        cleanup()
        currentSong = song
        currentTime = 0
        duration = 0
        state = .loading
        onSongStarted?(song)

        // Prefer the local cached file if we have it (offline-first).
        let playbackURL = MediaCacheService.shared.localURL(for: remoteURL, kind: .audio) ?? remoteURL
        // Fire-and-forget prefetch of preview + artwork so this song works offline next time.
        MediaCacheService.shared.prefetch(song: song)

        let playerItem = AVPlayerItem(url: playbackURL)
        player = AVPlayer(playerItem: playerItem)
        player?.automaticallyWaitsToMinimizeStalling = false

        statusObservation = playerItem.observe(\.status) { [weak self] item, _ in
            Task { @MainActor in
                guard let self else { return }
                switch item.status {
                case .readyToPlay:
                    self.duration = item.duration.seconds.isNaN ? 0 : item.duration.seconds
                    self.player?.play()
                    self.state = .playing
                    self.updateNowPlayingInfo()
                case .failed:
                    self.state = .idle
                default:
                    break
                }
            }
        }

        // 60fps interval for fluid slider movement
        let interval = CMTime(value: 1, timescale: 60)
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            // Already on main queue — use assumeIsolated to avoid async Task overhead
            MainActor.assumeIsolated {
                guard let self else { return }
                let seconds = time.seconds
                guard !seconds.isNaN else { return }
                if self.isSeeking { return }
                self.currentTime = seconds
                // Update lock screen at ~1fps (enough for the lock screen display)
                if Int(seconds * 4) % 4 == 0 {
                    var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
                    info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = seconds
                    MPNowPlayingInfoCenter.default().nowPlayingInfo = info
                }
            }
        }

        didFinishObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if self.autoPlayEnabled {
                    self.playNext()
                } else {
                    self.state = .idle
                    self.currentTime = self.duration
                    self.updateNowPlayingInfo()
                }
            }
        }
    }

    func togglePlayPause() {
        if state == .playing {
            player?.pause()
            state = .paused
        } else if state == .paused {
            player?.play()
            state = .playing
        } else if state == .idle, let song = currentSong {
            if let player {
                // Player still alive (song ended but not cleaned up).
                // Seek to wherever the slider currently is, then play.
                let resumeTime = max(0, min(currentTime, duration))
                let seekTarget = CMTime(seconds: resumeTime, preferredTimescale: 600)
                state = .loading
                player.seek(to: seekTarget) { [weak self] _ in
                    Task { @MainActor in
                        guard let self else { return }
                        self.player?.play()
                        self.state = .playing
                        self.updateNowPlayingInfo()
                    }
                }
            } else {
                // Player was fully cleaned up — recreate it.
                play(song: song)
            }
            return
        }
        updateNowPlayingInfo()
    }

    func seek(to progress: Double) {
        guard let player, duration > 0 else { return }
        let targetTime = progress * duration
        let time = CMTime(seconds: targetTime, preferredTimescale: 600)
        currentTime = targetTime
        isSeeking = true
        seekGuardTask?.cancel()
        player.seek(to: time) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.isSeeking = false
            }
        }
        // Failsafe: never let isSeeking get stuck (e.g. if completion never fires)
        seekGuardTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard let self, !Task.isCancelled else { return }
            self.isSeeking = false
        }
        if state == .playing {
            player.play()
        }
        updateNowPlayingInfo()
    }

    func playNext() {
        guard !playlist.isEmpty else {
            state = .idle
            updateNowPlayingInfo()
            return
        }
        let nextIndex = currentIndex + 1
        if nextIndex < playlist.count {
            currentIndex = nextIndex
            play(song: playlist[nextIndex])
        } else {
            state = .idle
            currentTime = 0
            updateNowPlayingInfo()
        }
    }

    func playPrevious() {
        guard !playlist.isEmpty else { return }
        if currentTime > 3 {
            seek(to: 0)
            return
        }
        let previousIndex = currentIndex - 1
        if previousIndex >= 0 {
            currentIndex = previousIndex
            play(song: playlist[previousIndex])
        } else {
            seek(to: 0)
        }
    }

    private func cleanup() {
        seekGuardTask?.cancel()
        seekGuardTask = nil
        isSeeking = false
        if let timeObserver, let player {
            player.removeTimeObserver(timeObserver)
        }
        timeObserver = nil
        statusObservation?.invalidate()
        statusObservation = nil
        if let didFinishObserver {
            NotificationCenter.default.removeObserver(didFinishObserver)
        }
        didFinishObserver = nil
        player?.pause()
        player = nil
    }

}
