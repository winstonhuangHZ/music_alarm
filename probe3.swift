import SwiftUI
import AppKit

struct ImportedAudioX: Identifiable {
    let id = UUID()
    let name: String
    let urlString: String
}

final class MiniStore: ObservableObject {
    @Published var audios: [ImportedAudioX] = []
    @discardableResult
    func importAudio() -> ImportedAudioX? { return nil }
    func addAlarm() {}
}

struct Probe3View: View {
    @EnvironmentObject var store: MiniStore
    @State private var selectedAudioID: UUID?

    var body: some View {
        VStack {
            // Button A: if-let action closure + .bordered
            Button(action: {
                if let audio = store.importAudio() {
                    selectedAudioID = audio.id
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "folder")
                    Text("Import Music")
                }
            }
            .buttonStyle(.bordered)

            // Button B: method reference + .borderedProminent
            Button(action: saveAlarm) {
                Text("Save")
            }
            .buttonStyle(.borderedProminent)

            // The audio selection list
            ScrollView {
                VStack(spacing: 6) {
                    ForEach(store.audios) { audio in
                        HStack(spacing: 10) {
                            Image(systemName: self.selectedAudioID == audio.id ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(self.selectedAudioID == audio.id ? Color.accentColor : .secondary)
                            Text(audio.name)
                            Spacer()
                        }
                        .onTapGesture { self.selectedAudioID = audio.id }
                    }
                }
            }
        }
    }

    private func saveAlarm() {
        store.addAlarm()
    }
}

print("OK")
