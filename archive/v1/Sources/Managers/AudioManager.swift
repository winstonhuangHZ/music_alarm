import Foundation
import AVFoundation
import AppKit
import Combine

/// Audio playback engine built on AVAudioPlayer (perfect .m4a / .mp3 decoding).
/// Supports normal preview playback and alarm ringing with a smooth volume
/// fade-in from 0 up to the target volume over a configurable duration.
final class AudioManager: NSObject, ObservableObject {
    @Published private(set) var isPlaying = false
    @Published private(set) var currentURL: URL?
    @Published private(set) var nowPlayingName: String?

    private var player: AVAudioPlayer?
    private var fadeTimer: Timer?
    private var isRinging = false

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
        p.play()
        player = p
        currentURL = url
        nowPlayingName = name
        isPlaying = true
    }

    // MARK: - Alarm ringing (progressive volume fade-in)

    /// Starts looping playback with a fade-in from volume 0 to `targetVolume`
    /// over `fadeDuration` seconds (15–30 s recommended).
    func ring(url: URL, name: String?, fadeDuration: TimeInterval = 20, targetVolume: Float = 0.85) {
        stop()
        guard let p = makePlayer(url: url) else {
            ringFallback()
            return
        }
        isRinging = true
        p.volume = 0
        p.numberOfLoops = -1 // loop until stopped
        p.play()
        player = p
        currentURL = url
        nowPlayingName = name
        isPlaying = true
        startFade(to: targetVolume, duration: fadeDuration)
    }

    /// Fallback system beep used when no audio file is configured.
    func ringFallback() {
        if let sound = NSSound(named: "Glass") {
            sound.play()
        }
    }

    private func makePlayer(url: URL) -> AVAudioPlayer? {
        do {
            let p = try AVAudioPlayer(contentsOf: url)
            p.delegate = self
            p.prepareToPlay()
            return p
        } catch {
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

    func stop() {
        fadeTimer?.invalidate()
        fadeTimer = nil
        player?.stop()
        player = nil
        currentURL = nil
        nowPlayingName = nil
        isPlaying = false
        isRinging = false
    }
}

extension AudioManager: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            if !self.isRinging {
                self.isPlaying = false
                self.currentURL = nil
                self.nowPlayingName = nil
            }
        }
    }
}
