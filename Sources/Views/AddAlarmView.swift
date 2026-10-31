import SwiftUI

/// Sheet used to create a new alarm or edit an existing one: time, repeat
/// type, and an ordered playlist of local audio tracks.
struct AddAlarmView: View {
    @EnvironmentObject var store: AlarmStore
    @Environment(\.presentationMode) private var presentationMode

    private let editingAlarm: AlarmItem?

    @State private var selectedTime: Date
    @State private var repeatType: RepeatType = .once

    /// The editable local track list for this alarm.
    @State private var tracks: [AudioTrack] = []
    /// Selected local audio in the import picker.
    @State private var selectedAudioID: UUID?
    @State private var audioNeedsSelection = false
    @State private var requiresWakeConfirmation = false

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
            _tracks = State(initialValue: alarm.tracks)
            _audioNeedsSelection = State(initialValue: alarm.audioNeedsSelection)
            _requiresWakeConfirmation = State(initialValue: alarm.requiresWakeConfirmation)
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

            VStack(alignment: .leading, spacing: 5) {
                Toggle(isOn: $requiresWakeConfirmation) {
                    Text(L("Require wake-up confirmation"))
                        .font(.headline)
                }
                Text(L("You can stop the sound, but the alarm stays unconfirmed until you say you are really awake."))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            playlistSection

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
                .disabled(self.tracks.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 480)
    }

    // MARK: - Playlist builder section

    private var playlistSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L("Playlist"))
                .font(.headline)

            // Track list (ordered playlist)
            if !tracks.isEmpty {
                trackList
            } else {
                Text(L("No tracks yet. Add local files below."))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            Text(L("Add Track"))
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            addLocalTrack
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Track list

    private var trackList: some View {
        ScrollView {
            VStack(spacing: 8) {
                ForEach(Array(tracks.enumerated()), id: \.offset) { idx, track in
                    self.trackRow(track, at: idx)
                }
            }
            .padding(4)
        }
        .frame(maxHeight: 150)
    }

    /// One editable row in the playlist: icon + name + reorder/remove buttons.
    private func trackRow(_ track: AudioTrack, at idx: Int) -> some View {
        let row = HStack(spacing: 10) {
            Text(track.icon)
                .font(.system(size: 14))
            Text(track.displayName)
                .font(.caption)
                .lineLimit(1)
            Spacer()
            if idx > 0 {
                Button(action: { self.moveTrackUp(idx) }) {
                    Text("▲").font(.system(size: 12))
                }
                .buttonStyle(PlainButtonStyle())
            }
            if idx < tracks.count - 1 {
                Button(action: { self.moveTrackDown(idx) }) {
                    Text("▼").font(.system(size: 12))
                }
                .buttonStyle(PlainButtonStyle())
            }
            Button(action: { self.removeTrack(at: idx) }) {
                Text("✖️").font(.system(size: 12))
            }
            .buttonStyle(PlainButtonStyle())
        }
        return row
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(NSColor.controlBackgroundColor))
            )
    }

    // MARK: - Add local track

    private var addLocalTrack: some View {
        VStack(spacing: 8) {
            if audioNeedsSelection {
                Text(L("This alarm needs a local audio file. Select one below."))
                    .font(.caption)
                    .foregroundColor(.orange)
            }
            if store.importedAudios.isEmpty {
                Text(L("No music imported yet. Import a song to use as the alarm sound."))
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                importPreviewList
            }

            HStack(spacing: 16) {
                Button(action: {
                    if let audio = self.store.importAudio() {
                        self.selectedAudioID = audio.id
                        self.addSelectedLocal()
                    }
                }) {
                    HStack(spacing: 6) {
                        Text("📁")
                        Text(L("Import & Add"))
                    }
                }
                if selectedAudioID != nil {
                    Button(action: { self.addSelectedLocal() }) {
                        HStack(spacing: 6) {
                            Text("➕")
                            Text(L("Add to Playlist"))
                        }
                    }
                }
            }
        }
    }

    private var importPreviewList: some View {
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
        .frame(maxHeight: 120)
    }

    private func addSelectedLocal() {
        guard let id = selectedAudioID,
              let audio = store.importedAudios.first(where: { $0.id == id }) else { return }
        tracks.append(.local(name: audio.name, path: audio.urlString, audioID: audio.id))
        selectedAudioID = nil
    }

    // MARK: - Track list manipulation

    private func removeTrack(at index: Int) {
        tracks.remove(at: index)
    }

    private func moveTrackUp(_ index: Int) {
        guard index > 0 else { return }
        tracks.swapAt(index, index - 1)
    }

    private func moveTrackDown(_ index: Int) {
        guard index < tracks.count - 1 else { return }
        tracks.swapAt(index, index + 1)
    }

    // MARK: - Save

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
        alarm.tracks = tracks
        alarm.audioNeedsSelection = false
        alarm.requiresWakeConfirmation = requiresWakeConfirmation

        if editingAlarm != nil {
            store.updateAlarm(alarm)
        } else {
            store.addAlarm(alarm)
        }
        presentationMode.wrappedValue.dismiss()
    }
}
