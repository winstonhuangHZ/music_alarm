import SwiftUI

/// Sheet used to create a new alarm or edit an existing one: time, repeat
/// type, and an ordered playlist of local audio tracks.
struct AddAlarmView: View {
    @EnvironmentObject var store: AlarmStore
    @Environment(\.presentationMode) private var presentationMode
    @ObservedObject private var settings = AppSettings.shared

    private let editingAlarm: AlarmItem?

    @State private var selectedTime: Date
    @State private var repeatType: RepeatType = .once
    @State private var label = ""
    @State private var scheduledDate: Date
    @State private var selectedWeekdays: Set<Int> = []

    /// The editable local track list for this alarm.
    @State private var tracks: [AudioTrack] = []
    /// Selected local audio in the import picker.
    @State private var selectedAudioID: UUID?
    @State private var audioNeedsSelection = false
    @State private var requiresWakeConfirmation = false
    @State private var fadeDurationSeconds = 20
    @State private var targetVolumePercent = 85
    @State private var maximumPlaybackMinutes = 30
    @State private var loopsPlaylist = true
    @State private var snoozeMinutes = 5

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
            _label = State(initialValue: alarm.label)
            _scheduledDate = State(initialValue: alarm.scheduledDate ?? cal.date(from: comps) ?? now)
            _selectedWeekdays = State(initialValue: alarm.weekdays)
            _tracks = State(initialValue: alarm.tracks)
            _audioNeedsSelection = State(initialValue: alarm.tracks.isEmpty || !alarm.tracks.contains(where: \.isPlayable))
            _requiresWakeConfirmation = State(initialValue: alarm.requiresWakeConfirmation)
            _fadeDurationSeconds = State(initialValue: alarm.fadeDurationSeconds)
            _targetVolumePercent = State(initialValue: alarm.targetVolumePercent)
            _maximumPlaybackMinutes = State(initialValue: alarm.maximumPlaybackMinutes)
            _loopsPlaylist = State(initialValue: alarm.loopsPlaylist)
            _snoozeMinutes = State(initialValue: alarm.snoozeMinutes)
        } else {
            comps.hour = 7
            comps.minute = 0
            _selectedTime = State(initialValue: cal.date(from: comps) ?? now)
            _scheduledDate = State(initialValue: cal.date(from: comps) ?? now)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(editingAlarm == nil ? L("Add Alarm") : L("Edit Alarm"))
                        .font(.system(size: 26, weight: .bold))

                    if repeatType == .once {
                        DatePicker(L("Date and time"), selection: $scheduledDate, displayedComponents: [.date, .hourAndMinute])
                    } else {
                        HStack(spacing: 16) {
                            DatePicker(L("Time"), selection: $selectedTime, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                            Spacer()
                        }
                    }

                    TextField(L("Label"), text: $label)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(L("Repeat"))
                            .font(.headline)
                        Picker(selection: $repeatType, label: Text(L("Repeat"))) {
                            ForEach(RepeatType.allCases) { type in
                                Text(type.title).tag(type)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        if repeatType == .custom {
                            weekdayPicker
                        }
                    }

                    VStack(alignment: .leading, spacing: 5) {
                        if settings.wakeConfirmationEnabled {
                            Toggle(isOn: $requiresWakeConfirmation) {
                                Text(L("Require wake-up confirmation"))
                                    .font(.headline)
                            }
                            Text(L("You can stop the sound, but the alarm stays unconfirmed until you say you are really awake."))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text(L("Wake-up confirmation is disabled in Settings."))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    playbackSection

                    playlistSection
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, 4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

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
                .disabled(self.tracks.isEmpty || (repeatType == .custom && selectedWeekdays.isEmpty))
            }
        }
        .padding(24)
        .frame(width: 480, height: 640)
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

    private var playbackSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L("Playback settings"))
                .font(.headline)
            Picker(L("Fade in"), selection: $fadeDurationSeconds) {
                Text(L("No fade")).tag(0)
                Text(L("5 seconds")).tag(5)
                Text(L("10 seconds")).tag(10)
                Text(L("20 seconds")).tag(20)
                Text(L("30 seconds")).tag(30)
                Text(L("60 seconds")).tag(60)
            }
            Picker(L("Target volume"), selection: $targetVolumePercent) {
                ForEach([50, 65, 75, 85, 100], id: \.self) { value in
                    Text("\(value)%").tag(value)
                }
            }
            Picker(L("Maximum playback"), selection: $maximumPlaybackMinutes) {
                Text(L("Until stopped")).tag(0)
                Text(L("5 minutes")).tag(5)
                Text(L("15 minutes")).tag(15)
                Text(L("30 minutes")).tag(30)
                Text(L("60 minutes")).tag(60)
                Text(L("120 minutes")).tag(120)
            }
            Picker(L("Snooze duration"), selection: $snoozeMinutes) {
                Text(L("1 minute")).tag(1)
                Text(L("5 minutes")).tag(5)
                Text(L("10 minutes")).tag(10)
                Text(L("15 minutes")).tag(15)
                Text(L("30 minutes")).tag(30)
            }
            Toggle(L("Loop the playlist"), isOn: $loopsPlaylist)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Track list

    private var trackList: some View {
        VStack(spacing: 8) {
            ForEach(Array(tracks.enumerated()), id: \.offset) { idx, track in
                self.trackRow(track, at: idx)
            }
        }
        .padding(4)
    }

    /// One editable row in the playlist: icon + name + reorder/remove buttons.
    private func trackRow(_ track: AudioTrack, at idx: Int) -> some View {
        let row = HStack(spacing: 10) {
            Image(systemName: track.icon)
                .font(.system(size: 14, weight: .medium))
            Text(track.displayName)
                .font(.caption)
                .lineLimit(1)
            Text(track.availability.title)
                .font(.caption2)
                .foregroundColor(track.isPlayable ? .green : .orange)
            Spacer()
            if !track.isPlayable {
                Menu {
                    Button(L("Replace Audio")) { self.replaceTrackFromFile(at: idx) }
                    if !store.importedAudios.isEmpty {
                        Menu(L("Choose from music library")) {
                            ForEach(store.importedAudios) { audio in
                                Button(audio.name) { self.replaceTrack(at: idx, with: audio) }
                            }
                        }
                    }
                } label: {
                    Text(L("Repair"))
                        .font(.caption2)
                }
            }
            if idx > 0 {
                Button(action: { self.moveTrackUp(idx) }) {
                    Image(systemName: "chevron.up").font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(PlainButtonStyle())
            }
            if idx < tracks.count - 1 {
                Button(action: { self.moveTrackDown(idx) }) {
                    Image(systemName: "chevron.down").font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(PlainButtonStyle())
            }
            Button(action: { self.removeTrack(at: idx) }) {
                Image(systemName: "xmark").font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(PlainButtonStyle())
        }
        return row
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(minHeight: 36)
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
                        Image(systemName: "folder")
                        Text(L("Import & Add"))
                    }
                }
                if selectedAudioID != nil {
                    Button(action: { self.addSelectedLocal() }) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus")
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
                        let track = AudioTrack.local(name: audio.name, path: audio.urlString, audioID: audio.id)
                        Text(track.availability.title)
                            .font(.caption2)
                            .foregroundColor(track.isPlayable ? .green : .orange)
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
        audioNeedsSelection = tracks.isEmpty || !tracks.contains(where: \.isPlayable)
    }

    private var weekdayPicker: some View {
        HStack(spacing: 4) {
            ForEach(1...7, id: \.self) { weekday in
                Button(calendarWeekdayTitle(weekday)) {
                    if selectedWeekdays.contains(weekday) {
                        selectedWeekdays.remove(weekday)
                    } else {
                        selectedWeekdays.insert(weekday)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(selectedWeekdays.contains(weekday) ? Color.accentColor : Color.secondary.opacity(0.15))
                .foregroundColor(selectedWeekdays.contains(weekday) ? .white : .primary)
                .cornerRadius(5)
            }
        }
    }

    private func calendarWeekdayTitle(_ weekday: Int) -> String {
        let symbols = Calendar.current.veryShortWeekdaySymbols
        return symbols.indices.contains(weekday - 1) ? symbols[weekday - 1] : "?"
    }

    private func replaceTrack(at index: Int, with audio: ImportedAudio) {
        guard tracks.indices.contains(index) else { return }
        tracks[index] = .local(name: audio.name, path: audio.urlString, audioID: audio.id)
        audioNeedsSelection = tracks.isEmpty || !tracks.contains(where: \.isPlayable)
    }

    private func replaceTrackFromFile(at index: Int) {
        guard tracks.indices.contains(index),
              case .local(_, _, let audioID) = tracks[index] else { return }
        if let replaced = store.replaceAudio(id: audioID) {
            replaceTrack(at: index, with: replaced)
        }
    }

    // MARK: - Track list manipulation

    private func removeTrack(at index: Int) {
        tracks.remove(at: index)
        audioNeedsSelection = tracks.isEmpty || !tracks.contains(where: \.isPlayable)
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

        let time = repeatType == .once ? scheduledDate : selectedTime
        alarm.hour = Calendar.current.component(.hour, from: time)
        alarm.minute = Calendar.current.component(.minute, from: time)
        alarm.repeatType = repeatType
        alarm.label = label.trimmingCharacters(in: .whitespacesAndNewlines)
        alarm.scheduledDate = repeatType == .once ? scheduledDate : nil
        alarm.weekdays = repeatType == .custom ? selectedWeekdays : []
        alarm.tracks = tracks
        alarm.audioNeedsSelection = tracks.isEmpty || !tracks.contains(where: \.isPlayable)
        alarm.requiresWakeConfirmation = settings.wakeConfirmationEnabled && requiresWakeConfirmation
        alarm.fadeDurationSeconds = fadeDurationSeconds
        alarm.targetVolumePercent = targetVolumePercent
        alarm.maximumPlaybackMinutes = maximumPlaybackMinutes
        alarm.loopsPlaylist = loopsPlaylist
        alarm.snoozeMinutes = snoozeMinutes

        if editingAlarm != nil {
            store.updateAlarm(alarm)
        } else {
            store.addAlarm(alarm)
        }
        presentationMode.wrappedValue.dismiss()
    }
}
