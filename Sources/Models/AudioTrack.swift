import Foundation

/// A single track in an alarm's playlist — can be a local audio file or
/// a Spotify link (playlist, album, or single track).
enum AudioTrack: Identifiable, Codable, Equatable {
    case local(name: String, path: String, audioID: UUID)
    case spotify(link: String)

    var id: String {
        switch self {
        case .local(_, _, let uuid): return "local-\(uuid.uuidString)"
        case .spotify(let link): return "spotify-\(link)"
        }
    }

    /// Human-readable display name for the track.
    var displayName: String {
        switch self {
        case .local(let name, _, _): return name
        case .spotify(let link):
            let parsed = SpotifySupport.spotifyType(from: link)
            return parsed.displayShort
        }
    }

    /// Whether the track is currently playable.
    var isPlayable: Bool {
        switch self {
        case .local(_, let path, _):
            return FileManager.default.fileExists(atPath: path)
        case .spotify(let link):
            return SpotifySupport.spotifyType(from: link).isValid
        }
    }

    /// Icon to represent the source.
    var icon: String {
        switch self {
        case .local: return "🎵"
        case .spotify: return "🎧"
        }
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey { case type, name, path, audioID, link }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(String.self, forKey: .type)
        switch type {
        case "local":
            let name = try c.decode(String.self, forKey: .name)
            let path = try c.decode(String.self, forKey: .path)
            let uuid = try c.decode(UUID.self, forKey: .audioID)
            self = .local(name: name, path: path, audioID: uuid)
        default:
            let link = try c.decode(String.self, forKey: .link)
            self = .spotify(link: link)
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .local(let name, let path, let uuid):
            try c.encode("local", forKey: .type)
            try c.encode(name, forKey: .name)
            try c.encode(path, forKey: .path)
            try c.encode(uuid, forKey: .audioID)
        case .spotify(let link):
            try c.encode("spotify", forKey: .type)
            try c.encode(link, forKey: .link)
        }
    }
}