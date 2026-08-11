import Foundation
import AppKit

/// Pure, side-effect-free helpers for parsing Spotify playlist links / URIs.
enum SpotifySupport {
    /// Extracts the playlist ID from a Spotify share URL or URI.
    /// Examples:
    ///   "https://open.spotify.com/playlist/37i9dQZF1DXcBWIGoYBM5M?si=abc"
    ///   "spotify:playlist:37i9dQZF1DXcBWIGoYBM5M"
    static func playlistID(from input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // URI form: spotify:playlist:<ID>
        let uriPrefix = "spotify:playlist:"
        if trimmed.hasPrefix(uriPrefix) {
            return validPlaylistID(String(trimmed.dropFirst(uriPrefix.count)))
        }

        // URL form: https://open.spotify.com/playlist/<ID>?...
        if let url = URL(string: trimmed),
           let host = url.host?.lowercased(),
           host == "open.spotify.com",
           url.pathComponents.count >= 3,
           url.pathComponents[1] == "playlist" {
            return validPlaylistID(url.pathComponents[2])
        }

        return nil
    }

    /// Builds the canonical `spotify:playlist:<ID>` URI used by AppleScript.
    static func playlistURI(from input: String) -> String? {
        guard let id = playlistID(from: input) else { return nil }
        return "spotify:playlist:\(id)"
    }

    private static func validPlaylistID(_ id: String) -> String? {
        let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 64 else { return nil }
        guard trimmed.range(of: "^[A-Za-z0-9]+$", options: .regularExpression) != nil else { return nil }
        return trimmed
    }
}

/// Controls the Spotify desktop app via AppleScript (no external SDK required).
final class SpotifyBridge {
    static let shared = SpotifyBridge()

    private static let spotifyBundleID = "com.spotify.client"

    /// Whether the Spotify macOS app is currently running.
    var isSpotifyRunning: Bool {
        NSWorkspace.shared.runningApplications.contains {
            $0.bundleIdentifier == SpotifyBridge.spotifyBundleID
        }
    }

    /// Whether Spotify is installed on this Mac.
    var isSpotifyInstalled: Bool {
        if let _ = NSWorkspace.shared.urlForApplication(withBundleIdentifier: SpotifyBridge.spotifyBundleID) {
            return true
        }
        return FileManager.default.fileExists(atPath: "/Applications/Spotify.app")
    }

    /// Executes an AppleScript snippet; returns whether it succeeded.
    @discardableResult
    private func runAppleScript(_ source: String) -> Bool {
        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else {
            NSLog("SpotifyBridge: failed to build AppleScript")
            return false
        }
        script.executeAndReturnError(&error)
        if let error = error {
            NSLog("SpotifyBridge: AppleScript error: %@", error)
            return false
        }
        return true
    }

    /// Brings Spotify to the foreground.
    @discardableResult
    func activate() -> Bool {
        runAppleScript("tell application \"Spotify\" to activate")
    }

    /// Turns shuffle OFF and starts playing a playlist in order.
    /// Returns false if Spotify is missing / not running / the link is invalid,
    /// so the caller can fall back to the built-in sound.
    func playPlaylist(from link: String) -> Bool {
        guard let uri = SpotifySupport.playlistURI(from: link) else {
            NSLog("SpotifyBridge: invalid playlist link: %@", link)
            return false
        }
        guard isSpotifyRunning else {
            NSLog("SpotifyBridge: Spotify is not running; falling back to built-in sound")
            return false
        }

        // 1) Activate Spotify.
        _ = activate()

        // 2) Disable shuffle so the playlist plays in order.
        if !runAppleScript("tell application \"Spotify\" to set shuffle enabled to false") {
            NSLog("SpotifyBridge: could not disable shuffle (non-fatal)")
        }

        // 3) Start sequential playback of the playlist.
        let ok = runAppleScript("tell application \"Spotify\" to play track \"\(uri)\"")
        if !ok {
            NSLog("SpotifyBridge: failed to start playlist playback")
        }
        return ok
    }

    /// Pauses Spotify playback (used when the user stops or snoozes an alarm).
    @discardableResult
    func pause() -> Bool {
        guard isSpotifyRunning else { return false }
        return runAppleScript("tell application \"Spotify\" to pause")
    }
}
