import Foundation
import AVFoundation
import AppKit
import Combine
import MediaPlayer

/// Audio playback engine built on AVAudioPlayer (perfect .m4a / .mp3 decoding).
final class AudioManager: NSObject, ObservableObject {
    @Published private(set) var isPlaying = false
    @Published private(set) var currentURL: URL?
    @Published private(set) var nowPlayingName: String?
    @Published private(set) var playbackProgress: Double = 0
    @Published private(set) var playbackDuration: TimeInterval = 0
    private(set) var lastPlaybackError: String?

    /// Called when a local track finishes during alarm ringing (for
    /// sequential playlist support — advances to the next track).
    var onTrackFinished: (() -> Void)?

    private var player: AVAudioPlayer?
    private var fadeTimer: Timer?
    private var progressTimer: Timer?
    private var isRinging = false
    private var fallbackSound: NSSound?

    // MARK: - Preview playback

    func togglePreview(url: URL, name: String) {
        if isPlaying, currentURL == url {
            stop()
        } else {
            playPreview(url: url, name: name)
        }
    }

    func playPreview(url: URL, name: String) {
        stop()
        guard let p = makePlayer(url: url) else { return }
        p.volume = 1.0
        p.numberOfLoops = 0
        guard p.play() else { return }
        player = p
        currentURL = url
        nowPlayingName = name
        isPlaying = true
        startProgressUpdates()
        updateNowPlayingInfo()
    }

    // MARK: - Alarm ringing

    @discardableResult
    func ring(url: URL, name: String?, numberOfLoops: Int = -1,
              fadeDuration: TimeInterval = 20, targetVolume: Float = 0.85) -> Bool {
        stop()
        lastPlaybackError = nil
        guard let p = makePlayer(url: url) else {
            return false
        }
        isRinging = true
        let safeTargetVolume = min(max(targetVolume, 0), 1)
        p.volume = fadeDuration > 0 ? 0 : safeTargetVolume
        p.numberOfLoops = numberOfLoops
        guard p.play() else {
            stop()
            return false
        }
        player = p
        currentURL = url
        nowPlayingName = name
        isPlaying = true
        startProgressUpdates()
        updateNowPlayingInfo()
        if fadeDuration > 0 {
            startFade(to: safeTargetVolume, duration: fadeDuration)
        }
        return true
    }

    @discardableResult
    func ringFallback(name: String = "Glass") -> Bool {
        stop()
        lastPlaybackError = nil
        guard let sound = NSSound(named: name) else {
            lastPlaybackError = String(format: L("Fallback sound is unavailable: %@"), name)
            return false
        }
        sound.loops = true
        guard sound.play() else {
            lastPlaybackError = String(format: L("Fallback sound could not start: %@"), name)
            return false
        }
        isRinging = true
        isPlaying = true
        nowPlayingName = L("System fallback sound")
        fallbackSound = sound
        updateNowPlayingInfo()
        return true
    }

    private func makePlayer(url: URL) -> AVAudioPlayer? {
        do {
            let p = try AVAudioPlayer(contentsOf: url)
            p.delegate = self
            p.prepareToPlay()
            return p
        } catch {
            lastPlaybackError = error.localizedDescription
            NSLog("AudioManager: failed to load %@: %@", url.path, error.localizedDescription)
            return nil
        }
    }

    private func startFade(to target: Float, duration: TimeInterval) {
        fadeTimer?.invalidate()
        let start = Date()
        fadeTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] timer in
            guard let self = self, let player = self.player else {
                timer.invalidate()
                return
            }
            let elapsed = Date().timeIntervalSince(start)
            let progress = min(max(elapsed / duration, 0), 1)
            player.volume = target * Float(progress)
            if progress >= 1 {
                timer.invalidate()
            }
        }
    }

    private func startProgressUpdates() {
        progressTimer?.invalidate()
        playbackProgress = 0
        playbackDuration = player?.duration ?? 0
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] timer in
            guard let self, let player = self.player else {
                timer.invalidate()
                return
            }
            self.playbackDuration = player.duration
            self.playbackProgress = player.duration > 0
                ? min(max(player.currentTime / player.duration, 0), 1)
                : 0
            self.updateNowPlayingInfo()
        }
    }

    private func updateNowPlayingInfo() {
        guard isPlaying else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: nowPlayingName ?? L("Music Alarm"),
            MPMediaItemPropertyArtist: L("Music Alarm"),
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: player?.currentTime ?? 0.0,
        ]
        if let player, player.duration > 0 {
            info[MPMediaItemPropertyPlaybackDuration] = player.duration
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    func stop() {
        fadeTimer?.invalidate()
        fadeTimer = nil
        progressTimer?.invalidate()
        progressTimer = nil
        player?.stop()
        player = nil
        fallbackSound?.stop()
        fallbackSound = nil
        currentURL = nil
        nowPlayingName = nil
        isPlaying = false
        playbackProgress = 0
        playbackDuration = 0
        isRinging = false
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }
}

extension AudioManager: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            guard self.player === player else { return }
            let wasRinging = self.isRinging

            // Clear the completed player before asking the engine to start the
            // next track. This makes the transition explicit and prevents the
            // old player from being mistaken for the active playback session.
            self.player = nil
            self.isPlaying = false
            self.currentURL = nil
            self.nowPlayingName = nil
            self.fadeTimer?.invalidate()
            self.fadeTimer = nil
            self.progressTimer?.invalidate()
            self.progressTimer = nil
            self.playbackProgress = 1
            self.playbackDuration = player.duration
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil

            if wasRinging {
                self.onTrackFinished?()
            }
        }
    }
}
