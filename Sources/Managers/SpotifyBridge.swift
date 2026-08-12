import Foundation
import AppKit

/// Identifies the type of a Spotify link so the app can play it appropriately.
enum SpotifyLinkType {
    case playlist(id: String)
    case track(id: String)
    case album(id: String)

    /// Whether the parser matched a known Spotify link.
    var isValid: Bool {
        switch self {
        case .playlist, .track, .album: return true
        }
    }

    /// A short human-readable label shown in the track list.
    var displayShort: String {
        switch self {
        case .playlist(let id): return String(format: "🎧 Playlist · %@", id)
        case .track(let id):    return String(format: "🎧 Track · %@", id)
        case .album(let id):    return String(format: "🎧 Album · %@", id)
        }
    }
}

/// Pure, side-effect-free helpers for parsing Spotify links / URIs.
enum SpotifySupport {
    /// Extracts the playlist ID from a Spotify share URL or URI.
    static func playlistID(from input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let uriPrefix = "spotify:playlist:"
        if trimmed.hasPrefix(uriPrefix) {
            return validID(String(trimmed.dropFirst(uriPrefix.count)))
        }
        if let url = URL(string: trimmed),
           let host = url.host?.lowercased(),
           host == "open.spotify.com",
           url.pathComponents.count >= 3,
           url.pathComponents[1] == "playlist" {
            return validID(url.pathComponents[2])
        }
        return nil
    }

    /// Determines the type and ID of any supported Spotify link.
    static func spotifyType(from input: String) -> SpotifyLinkType {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .playlist(id: "") }

        // URI prefixes
        if trimmed.hasPrefix("spotify:playlist:") {
            let id = String(trimmed.dropFirst("spotify:playlist:".count))
            return validID(id).map { .playlist(id: $0) } ?? .playlist(id: "")
        }
        if trimmed.hasPrefix("spotify:track:") {
            let id = String(trimmed.dropFirst("spotify:track:".count))
            return validID(id).map { .track(id: $0) } ?? .track(id: "")
        }
        if trimmed.hasPrefix("spotify:album:") {
            let id = String(trimmed.dropFirst("spotify:album:".count))
            return validID(id).map { .album(id: $0) } ?? .album(id: "")
        }

        // URL form
        if let url = URL(string: trimmed),
           let host = url.host?.lowercased(),
           host == "open.spotify.com",
           url.pathComponents.count >= 3 {
            let type = url.pathComponents[1]
            let id = validID(url.pathComponents[2])
            switch (type, id) {
            case ("playlist", let id?): return .playlist(id: id)
            case ("track",    let id?): return .track(id: id)
            case ("album",    let id?): return .album(id: id)
            default: break
            }
        }

        // fallback to old playlist-only check
        if let pid = playlistID(from: input) { return .playlist(id: pid) }
        return .playlist(id: "")
    }

    /// Builds the canonical `spotify:<type>:<ID>` URI used by AppleScript.
    static func spotifyURI(from input: String) -> String? {
        let type = spotifyType(from: input)
        guard type.isValid else { return nil }
        switch type {
        case .playlist(let id): return "spotify:playlist:\(id)"
        case .track(let id):    return "spotify:track:\(id)"
        case .album(let id):    return "spotify:album:\(id)"
        }
    }

    private static func validID(_ id: String) -> String? {
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

    var isSpotifyRunning: Bool {
        NSWorkspace.shared.runningApplications.contains {
            $0.bundleIdentifier == SpotifyBridge.spotifyBundleID
        }
    }

    var isSpotifyInstalled: Bool {
        if let _ = NSWorkspace.shared.urlForApplication(withBundleIdentifier: SpotifyBridge.spotifyBundleID) {
            return true
        }
        return FileManager.default.fileExists(atPath: "/Applications/Spotify.app")
    }

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

    @discardableResult
    func activate() -> Bool {
        runAppleScript("tell application \"Spotify\" to activate")
    }

    /// Plays a Spotify link (playlist, track, or album) via AppleScript.
    func playSpotify(from link: String) -> Bool {
        guard let uri = SpotifySupport.spotifyURI(from: link) else {
            NSLog("SpotifyBridge: invalid Spotify link: %@", link)
            return false
        }
        guard isSpotifyRunning else {
            NSLog("SpotifyBridge: Spotify is not running; falling back to built-in sound")
            return false
        }
        _ = activate()
        if !runAppleScript("tell application \"Spotify\" to set shuffle enabled to false") {
            NSLog("SpotifyBridge: could not disable shuffle (non-fatal)")
        }
        let ok = runAppleScript("tell application \"Spotify\" to play track \"\(uri)\"")
        if !ok {
            NSLog("SpotifyBridge: failed to start playback for %@", link)
        }
        return ok
    }

    @discardableResult
    func pause() -> Bool {
        guard isSpotifyRunning else { return false }
        return runAppleScript("tell application \"Spotify\" to pause")
    }
}