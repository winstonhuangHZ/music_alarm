import SwiftUI

/// Sheet used to create a new alarm or edit an existing one: time, repeat
/// type, and alarm sound (local audio file or a Spotify playlist link).
/// Pass `alarm` to edit an existing alarm; when `alarm == nil` a new alarm
/// is created.
struct AddAlarmView: View {
    @EnvironmentObject var store: AlarmStore
    @Environment(\.presentationMode) private var presentationMode

    private let editingAlarm: AlarmItem?

    @State private var selectedTime: Date
    @State private var repeatType: RepeatType = .once
    @State private var selectedAudioID: UUID?
    @State private var soundSource: AlarmSoundSource = .local
    @State private var spotifyLink = ""

    init(alarm: AlarmItem? = nil) {
        self.editingAlarm = alarm

        let cal = Calendar.current
        let now = Date()
        var comps = cal.dateComponents([.year, .month, .day], from: now)

        if let alarm = alarm {
            comps.hour = alarm.hour
            comps.minute = alarm.minute
            _selectedTime = State(initialValue: cal.date(from: comps) ?? now)
            _repeatType = State(initialValue: alarm.repeatType)
            _soundSource = State(initialValue: alarm.soundSource)
            if case .spotify = alarm.soundSource {
                _spotifyLink = State(initialValue: alarm.spotifyPlaylistURL ?? "")
            }
        } else {
            comps.hour = 7
            comps.minute = 0
            _selectedTime = State(initialValue: cal.date(from: comps) ?? now)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(editingAlarm == nil ? L("Add Alarm") : L("Edit Alarm"))
                .font(.system(size: 26, weight: .bold))

            HStack(spacing: 16) {
                DatePicker(L("Time"), selection: $selectedTime, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(L("Repeat"))
                    .font(.headline)
                Picker(selection: $repeatType, label: Text(L("Repeat"))) {
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
                    Text(L("Cancel"))
                }
                Button(action: { self.saveAlarm() }) {
                    Text(L("Save"))
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
        .onAppear {
            // Match the edited alarm's audio path to a library entry.
            // (Cannot access @EnvironmentObject during init.)
            if let alarm = self.editingAlarm, alarm.soundSource == .local {
                if let path = alarm.audioPath {
                    self.selectedAudioID = self.store.importedAudios.first { $0.urlString == path }?.id
                }
            }
        }
    }

    // MARK: - Alarm sound section

    private var soundSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L("Alarm Sound"))
                .font(.headline)

            Picker(selection: $soundSource, label: Text(L("Sound Source"))) {
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
                Text(L("No music imported yet. Import a song to use as the alarm sound."))
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
                    Text(L("Import Music…"))
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
            return L("Paste a Spotify playlist link — URL or spotify:playlist:…")
        }
        if spotifyLinkValid {
            return L("✓ Valid playlist — will play in order.")
        }
        return L("⚠️ Could not parse a Spotify playlist link.")
    }

    private var canSave: Bool {
        switch soundSource {
        case .local: return selectedAudioID != nil
        case .spotify: return spotifyLinkValid
        }
    }

    private func saveAlarm() {
        var alarm: AlarmItem
        if let existing = editingAlarm {
            alarm = existing
        } else {
            alarm = AlarmItem()
        }

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

        if editingAlarm != nil {
            store.updateAlarm(alarm)
        } else {
            store.addAlarm(alarm)
        }
        presentationMode.wrappedValue.dismiss()
    }
}