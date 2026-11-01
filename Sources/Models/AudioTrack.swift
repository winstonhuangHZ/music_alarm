import Foundation
import AVFoundation

enum AudioAvailability {
    case playable
    case missing
    case undecodable

    var title: String {
        switch self {
        case .playable: return L("Playable")
        case .missing: return L("File missing")
        case .undecodable: return L("File cannot be decoded")
        }
    }
}

/// A local track in an alarm playlist. `unavailable` is only a migration
/// placeholder for records created by older builds.
enum AudioTrack: Identifiable, Codable, Equatable {
    case local(name: String, path: String, audioID: UUID)
    case unavailable

    var id: String {
        switch self {
        case .local(_, _, let uuid): return "local-\(uuid.uuidString)"
        case .unavailable: return "unavailable"
        }
    }

    var displayName: String {
        switch self {
        case .local(let name, _, _): return name
        case .unavailable: return L("Audio unavailable")
        }
    }

    var isPlayable: Bool {
        switch self {
        case .local:
            return availability == .playable
        case .unavailable: return false
        }
    }

    var availability: AudioAvailability {
        switch self {
        case .local(_, let path, _):
            guard FileManager.default.fileExists(atPath: path) else { return .missing }
            guard let player = try? AVAudioPlayer(contentsOf: URL(fileURLWithPath: path)),
                  player.duration > 0 else { return .undecodable }
            return .playable
        case .unavailable:
            return .missing
        }
    }

    var icon: String {
        switch self {
        case .local: return "music.note"
        case .unavailable: return "exclamationmark.triangle.fill"
        }
    }

    enum CodingKeys: String, CodingKey { case type, name, path, audioID }

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
            // Older builds stored external streaming records here. Decode them
            // safely, then AlarmItem migration removes the placeholder and asks
            // the user to select local audio.
            self = .unavailable
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
        case .unavailable:
            try c.encode("unavailable", forKey: .type)
        }
    }
}
