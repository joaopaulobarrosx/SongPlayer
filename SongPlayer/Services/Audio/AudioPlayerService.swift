import AVFoundation
import Combine

@MainActor
@Observable
final class AudioPlayerService {
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

    nonisolated(unsafe) private var player: AVPlayer?
    nonisolated(unsafe) private var timeObserver: Any?
    private var statusObservation: NSKeyValueObservation?
    nonisolated(unsafe) private var didFinishObserver: NSObjectProtocol?

    var progress: Double {
        guard duration > 0 else { return 0 }
        return currentTime / duration
    }

    var playlist: [Song] = []
    var currentIndex: Int = 0

    init() {
        configureAudioSession()
    }

    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            // Audio session configuration failed
        }
    }

    func play(song: Song, playlist: [Song]? = nil, index: Int = 0) {
        if let playlist {
            self.playlist = playlist
            self.currentIndex = index
        }

        guard let urlString = song.previewUrl, let url = URL(string: urlString) else { return }

        cleanup()
        currentSong = song
        state = .loading

        let playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)

        statusObservation = playerItem.observe(\.status) { [weak self] item, _ in
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
            Task { @MainActor in
                guard let self else { return }
                self.currentTime = time.seconds.isNaN ? 0 : time.seconds
            }
        }

        didFinishObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.playNext()
            }
        }
    }

    func togglePlayPause() {
        guard let player else { return }
        if state == .playing {
            player.pause()
            state = .paused
        } else if state == .paused {
            player.play()
            state = .playing
        }
    }

    func seek(to progress: Double) {
        guard let player, duration > 0 else { return }
        let time = CMTime(seconds: progress * duration, preferredTimescale: 600)
        player.seek(to: time)
    }

    func playNext() {
        guard !playlist.isEmpty else {
            state = .idle
            return
        }
        let nextIndex = currentIndex + 1
        if nextIndex < playlist.count {
            currentIndex = nextIndex
            play(song: playlist[nextIndex])
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
        let previousIndex = currentIndex - 1
        if previousIndex >= 0 {
            currentIndex = previousIndex
            play(song: playlist[previousIndex])
        } else {
            seek(to: 0)
        }
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

    deinit {
        if let timeObserver, let player {
            player.removeTimeObserver(timeObserver)
        }
        if let didFinishObserver {
            NotificationCenter.default.removeObserver(didFinishObserver)
        }
    }
}
