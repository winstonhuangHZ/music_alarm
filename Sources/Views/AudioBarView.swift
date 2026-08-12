import SwiftUI

/// Bottom music library bar: import button + chips for each imported audio
/// with play / pause preview and remove actions.
struct AudioBarView: View {
    @EnvironmentObject var store: AlarmStore
    @EnvironmentObject var audioManager: AudioManager
    @EnvironmentObject var languageManager: LanguageManager

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            headerRow
            musicList
        }
        .padding(14)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var headerRow: some View {
        HStack(spacing: 10) {
            Text("🎵")
                .foregroundColor(Color.secondary)
            Text(L("Music Library"))
                .font(.headline)
            Spacer()
            Button(action: { self.store.importAudio() }) {
                HStack(spacing: 6) {
                    Text("➕")
                    Text(L("Import Music"))
                }
            }
        }
    }

    private var musicList: some View {
        Group {
            if store.importedAudios.isEmpty {
                Text(L("No music imported. Click “Import Music” to add .mp3 / .m4a files."))
                    .font(.caption)
                    .foregroundColor(Color.secondary)
                    .padding(.leading, 26)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(store.importedAudios) { audio in
                            self.audioChip(audio)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private func audioChip(_ audio: ImportedAudio) -> some View {
        let isCurrent = audioManager.currentURL == audio.url
        let playing = isCurrent && audioManager.isPlaying
        return HStack(spacing: 8) {
            Text(isCurrent ? "🔊" : "🎵")
                .foregroundColor(isCurrent ? Color.accentColor : Color.secondary)
            Text(audio.name)
                .font(.caption)
                .lineLimit(1)
            chipPlayButton(audio, playing: playing)
            chipRemoveButton(audio)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule().fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            Capsule().stroke(Color.accentColor.opacity(isCurrent ? 0.5 : 0), lineWidth: 1)
        )
    }

    private func chipPlayButton(_ audio: ImportedAudio, playing: Bool) -> some View {
        Button(action: {
            if audio.fileExists {
                self.audioManager.togglePreview(url: audio.url, name: audio.name)
            }
        }) {
            Text(playing ? "⏸" : "▶️")
                .font(.system(size: 14))
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!audio.fileExists)
    }

    private func chipRemoveButton(_ audio: ImportedAudio) -> some View {
        Button(action: {
            self.store.removeAudio(id: audio.id)
        }) {
            Text("✖️")
                .font(.system(size: 14))
        }
        .buttonStyle(PlainButtonStyle())
        .foregroundColor(Color.secondary)
    }
}
