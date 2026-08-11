import SwiftUI

/// Sheet used to create a new alarm: time, repeat type, and alarm sound
/// (local audio file or a Spotify playlist link).
struct AddAlarmView: View {
    @EnvironmentObject var store: AlarmStore
    @Environment(\.presentationMode) private var presentationMode

    @State private var selectedTime: Date
    @State private var repeatType: RepeatType = .once
    @State private var selectedAudioID: UUID?
    @State private var soundSource: AlarmSoundSource = .local
    @State private var spotifyLink = ""

    init() {
        let now = Date()
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: now)
        comps.hour = 7
        comps.minute = 0
        _selectedTime = State(initialValue: Calendar.current.date(from: comps) ?? now)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Add Alarm")
                .font(.system(size: 26, weight: .bold))

            HStack(spacing: 16) {
                DatePicker("Time", selection: $selectedTime, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Repeat")
                    .font(.headline)
                Picker(selection: $repeatType, label: Text("Repeat")) {
                    ForEach(RepeatType.allCases) { type in
                        Text(type.title).tag(type)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            }

            soundSection

            HStack {
                Spacer()
                Button(action: { self.presentationMode.wrappedValue.dismiss() }) {
                    Text("Cancel")
                }
                Button(action: { self.saveAlarm() }) {
                    Text("Save")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 7)
                        .background(Color.red)
                        .cornerRadius(7)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(!self.canSave)
            }
        }
        .padding(24)
        .frame(width: 440)
    }

    // MARK: - Alarm sound section

    private var soundSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Alarm Sound")
                .font(.headline)

            Picker(selection: $soundSource, label: Text("Sound Source")) {
                ForEach(AlarmSoundSource.allCases) { source in
                    Text(source.title).tag(source)
                }
            }
            .pickerStyle(SegmentedPickerStyle())

            if soundSource == .spotify {
                spotifyInput
            } else {
                localInput
            }
        }
    }

    private var localInput: some View {
        VStack(alignment: .leading, spacing: 8) {
            if store.importedAudios.isEmpty {
                Text("No music imported yet. Import a song to use as the alarm sound.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                audioSelectionList
            }

            Button(action: {
                if let audio = self.store.importAudio() {
                    self.selectedAudioID = audio.id
                }
            }) {
                HStack(spacing: 6) {
                    Text("📁")
                        .font(.system(size: 13))
                    Text("Import Music…")
                }
            }
        }
    }

    private var spotifyInput: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("https://open.spotify.com/playlist/...", text: $spotifyLink)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .font(.system(size: 13))
            Text(spotifyHintText)
                .font(.caption)
                .foregroundColor(spotifyLink.isEmpty ? Color.secondary : (spotifyLinkValid ? Color.green : Color.red))
        }
    }

    private var audioSelectionList: some View {
        ScrollView {
            VStack(spacing: 6) {
                ForEach(store.importedAudios) { audio in
                    HStack(spacing: 10) {
                        Text(self.selectedAudioID == audio.id ? "✓" : "○")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(self.selectedAudioID == audio.id ? Color.accentColor : .secondary)
                            .frame(width: 16)
                        Text(audio.name)
                            .lineLimit(1)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(self.selectedAudioID == audio.id
                                  ? Color.accentColor.opacity(0.12)
                                  : Color.clear)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        self.selectedAudioID = audio.id
                    }
                }
            }
            .padding(2)
        }
        .frame(maxHeight: 150)
    }

    // MARK: - Helpers

    private var spotifyLinkValid: Bool {
        SpotifySupport.playlistID(from: spotifyLink) != nil
    }

    private var spotifyHintText: String {
        if spotifyLink.isEmpty {
            return "Paste a Spotify playlist link — URL or spotify:playlist:…"
        }
        if spotifyLinkValid {
            return "✓ Valid playlist — will play in order."
        }
        return "⚠️ Could not parse a Spotify playlist link."
    }

    private var canSave: Bool {
        switch soundSource {
        case .local: return selectedAudioID != nil
        case .spotify: return spotifyLinkValid
        }
    }

    private func saveAlarm() {
        var alarm = AlarmItem()
        alarm.hour = Calendar.current.component(.hour, from: selectedTime)
        alarm.minute = Calendar.current.component(.minute, from: selectedTime)
        alarm.repeatType = repeatType
        alarm.soundSource = soundSource

        switch soundSource {
        case .local:
            if let id = selectedAudioID, let audio = store.importedAudios.first(where: { $0.id == id }) {
                alarm.audioName = audio.name
                alarm.audioPath = audio.urlString
            }
        case .spotify:
            alarm.spotifyPlaylistURL = spotifyLink.trimmingCharacters(in: .whitespacesAndNewlines)
            alarm.audioName = nil
            alarm.audioPath = nil
        }

        store.addAlarm(alarm)
        presentationMode.wrappedValue.dismiss()
    }
}
