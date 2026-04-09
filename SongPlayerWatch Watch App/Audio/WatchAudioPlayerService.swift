import Foundation
import AVFoundation
import Observation
import SongPlayerCore

/// watchOS playback service. Uses plain AVPlayer — MediaPlayer framework
/// (MPRemoteCommandCenter / MPNowPlayingInfoCenter) is not available on watchOS.
@MainActor
@Observable
final class WatchAudioPlayerService {
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

    var playlist: [Song] = []
    var currentIndex: Int = 0

    var progress: Double {
        guard duration > 0 else { return 0 }
        return currentTime / duration
    }

    init() {
        configureAudioSession()
    }

    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            // Session configuration failed — playback may not work over AirPods
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

        // Prefer the local cached file if we have it — this is how the Watch
        // plays back without internet (after the first download).
        let playbackURL = MediaCacheService.shared.localURL(for: remoteURL, kind: .audio) ?? remoteURL
        MediaCacheService.shared.prefetch(song: song)

        let item = AVPlayerItem(url: playbackURL)
        player = AVPlayer(playerItem: item)
        player?.automaticallyWaitsToMinimizeStalling = false

        statusObservation = item.observe(\.status) { [weak self] item, _ in
            Task { @MainActor in
                guard let self else { return }
                switch item.status {
                case .readyToPlay:
                    self.duration = item.duration.seconds.isNaN ? 0 : item.duration.seconds
                    self.player?.play()
                    self.state = .playing
                case .failed:
                    self.state = .idle
                default:
                    break
                }
            }
        }

        let interval = CMTime(seconds: 0.25, preferredTimescale: 600)
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            MainActor.assumeIsolated {
                guard let self else { return }
                let seconds = time.seconds
                guard !seconds.isNaN else { return }
                self.currentTime = seconds
            }
        }

        didFinishObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.playNext()
            }
        }
    }

    func togglePlayPause() {
        switch state {
        case .playing:
            player?.pause()
            state = .paused
        case .paused:
            player?.play()
            state = .playing
        case .idle:
            if let song = currentSong {
                play(song: song)
            }
        case .loading:
            break
        }
    }

    func playNext() {
        guard !playlist.isEmpty else {
            state = .idle
            return
        }
        let next = currentIndex + 1
        if next < playlist.count {
            currentIndex = next
            play(song: playlist[next])
        } else {
            state = .idle
            currentTime = 0
        }
    }

    func playPrevious() {
        guard !playlist.isEmpty else { return }
        if currentTime > 3 {
            seek(to: 0)
            return
        }
        let prev = currentIndex - 1
        if prev >= 0 {
            currentIndex = prev
            play(song: playlist[prev])
        } else {
            seek(to: 0)
        }
    }

    func seek(to progress: Double) {
        guard let player, duration > 0 else { return }
        let target = progress * duration
        currentTime = target
        player.seek(to: CMTime(seconds: target, preferredTimescale: 600))
    }

    private func cleanup() {
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
