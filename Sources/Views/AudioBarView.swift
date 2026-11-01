import SwiftUI
import AppKit

/// Compact entry point for the local audio library. The full library opens as
/// a trailing panel so the main alarm list keeps its vertical space.
struct AudioBarView: View {
    @EnvironmentObject var store: AlarmStore
    @EnvironmentObject var audioManager: AudioManager
    @Binding var isExpanded: Bool
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "music.note.list")
                .font(.system(size: 16, weight: .medium))
            VStack(alignment: .leading, spacing: 2) {
                Text(L("Music Library"))
                    .font(.headline)
                Text(librarySummary)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            if let currentName = currentPreviewName {
                HStack(spacing: 5) {
                    Image(systemName: "speaker.wave.2.fill")
                    Text(currentName)
                        .font(.caption)
                        .lineLimit(1)
                }
                .foregroundColor(.accentColor)
                .frame(maxWidth: 180, alignment: .trailing)
            }
            Button(action: { store.importAudio() }) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(BorderedButtonStyle())
            .help(L("Import Music"))
            .accessibilityLabel(L("Import Music"))
            Button(action: { withAnimation(.easeInOut(duration: 0.2)) { isExpanded = true } }) {
                HStack(spacing: 5) {
                    Image(systemName: "sidebar.right")
                    Text(L("Music Library"))
                }
            }
            .buttonStyle(BorderedButtonStyle())
            .accessibilityLabel(L("Open Music Library"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(ThemeSurfaceBackground(choice: settings.themeChoice))
    }

    private var librarySummary: String {
        if store.importedAudios.isEmpty {
            return L("No music imported. Click “Import Music” to add .mp3 / .m4a files.")
        }
        return String(format: L("%d tracks"), store.importedAudios.count)
    }

    private var currentPreviewName: String? {
        guard let currentURL = audioManager.currentURL else { return nil }
        return store.importedAudios.first(where: { $0.url == currentURL })?.name
    }
}

struct MusicLibraryPanel: View {
    @EnvironmentObject var store: AlarmStore
    @EnvironmentObject var audioManager: AudioManager
    @Binding var isPresented: Bool
    @ObservedObject private var settings = AppSettings.shared
    @State private var libraryMessage = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            Divider()
            if store.importedAudios.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(store.importedAudios) { audio in
                            audioRow(audio)
                        }
                    }
                }
            }
            Divider()
            libraryActions
            if !libraryMessage.isEmpty {
                Text(libraryMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }
        }
        .padding(18)
        .frame(width: 370, alignment: .topLeading)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(ThemeSurfaceBackground(choice: settings.themeChoice))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.accentColor.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.22), radius: 24, x: -8, y: 8)
        .accessibilityElement(children: .contain)
    }

    private var header: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(L("Music Library"))
                    .font(.title3.weight(.semibold))
                Text(String(format: L("%d tracks"), store.importedAudios.count))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button(action: { store.importAudio() }) {
                Image(systemName: "plus")
            }
            .buttonStyle(BorderedButtonStyle())
            .help(L("Import Music"))
            .accessibilityLabel(L("Import Music"))
            Button(action: { withAnimation(.easeInOut(duration: 0.2)) { isPresented = false } }) {
                Image(systemName: "xmark")
            }
            .buttonStyle(PlainButtonStyle())
            .foregroundColor(.secondary)
            .help(L("Close"))
            .accessibilityLabel(L("Close"))
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "music.note.list")
                .font(.system(size: 34, weight: .medium))
            Text(L("No music imported. Click “Import Music” to add .mp3 / .m4a files."))
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button(L("Import Music")) { store.importAudio() }
                .buttonStyle(BorderedButtonStyle())
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func audioRow(_ audio: ImportedAudio) -> some View {
        let isCurrent = audioManager.currentURL == audio.url
        let playing = isCurrent && audioManager.isPlaying
        return HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isCurrent ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.12))
                .frame(width: 34, height: 34)
                .overlay(
                    Image(systemName: isCurrent ? "speaker.wave.2.fill" : "music.note")
                        .font(.system(size: 14, weight: .medium))
                )
            VStack(alignment: .leading, spacing: 3) {
                Text(audio.name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Text(audio.fileExists ? L("Playable") : L("Missing"))
                    .font(.caption)
                    .foregroundColor(audio.fileExists ? .secondary : .orange)
            }
            Spacer(minLength: 4)
            Button(action: {
                guard audio.fileExists else { return }
                audioManager.togglePreview(url: audio.url, name: audio.name)
            }) {
                Image(systemName: playing ? "pause.fill" : "play.fill")
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(!audio.fileExists)
            .accessibilityLabel(playing ? L("Pause preview") : L("Preview Sound"))
            Button(action: { store.replaceAudio(id: audio.id) }) {
                Image(systemName: "arrow.triangle.2.circlepath")
            }
            .buttonStyle(PlainButtonStyle())
            .help(L("Replace Audio"))
            .accessibilityLabel(L("Replace Audio"))
            Button(action: { store.removeAudio(id: audio.id) }) {
                Image(systemName: "trash")
            }
            .buttonStyle(PlainButtonStyle())
            .foregroundColor(.secondary)
            .accessibilityLabel(L("Delete audio"))
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.72))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(isCurrent ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 1)
        )
    }

    private var libraryActions: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L("Audio library health"))
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
            HStack(spacing: 8) {
                Button(L("Scan audio library")) {
                    libraryMessage = store.audioLibraryReport().summary
                }
                Button(L("Remove orphaned files")) {
                    let count = store.removeOrphanedManagedAudioFiles()
                    libraryMessage = String(format: L("Removed %@ orphaned files"), "\(count)")
                }
                Button(L("Deduplicate audio")) {
                    let count = store.deduplicateAudioLibrary()
                    libraryMessage = String(format: L("Removed %@ duplicate items"), "\(count)")
                }
            }
            .font(.caption)
        }
    }
}
