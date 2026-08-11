import SwiftUI
import AppKit

// Probe 1: Picker with a Hashable, Identifiable, CaseIterable enum
enum RepeatType: String, Codable, CaseIterable, Identifiable, Hashable {
    case once = "Once"
    case daily = "Daily"
    case weekdays = "Weekdays"
    var id: String { rawValue }
    var title: String { rawValue }
}

struct ImportedAudio2: Identifiable {
    let id = UUID()
    let name: String
}

struct ProbeView: View {
    @State private var repeatType: RepeatType = .once
    @State private var selectedAudioID: UUID?
    let audios = [ImportedAudio2(name: "a"), ImportedAudio2(name: "b")]

    var body: some View {
        VStack {
            Picker("Repeat", selection: $repeatType) {
                ForEach(RepeatType.allCases) { type in
                    Text(type.title).tag(type)
                }
            }
            .pickerStyle(.segmented)

            ForEach(audios) { audio in
                HStack {
                    Image(systemName: self.selectedAudioID == audio.id ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(self.selectedAudioID == audio.id ? Color.accentColor : .secondary)
                    Text(audio.name)
                }
                .onTapGesture { self.selectedAudioID = audio.id }
            }
        }
    }
}

print("OK")
