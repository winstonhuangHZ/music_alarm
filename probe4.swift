import SwiftUI
import AppKit

struct ImportedAudioY: Identifiable {
    let id = UUID()
    let name: String
}

final class MiniStore2: ObservableObject {
    @discardableResult
    func importAudio() -> ImportedAudioY? { return nil }
    func addAlarm() {}
}

struct Probe4View: View {
    @EnvironmentObject var store: MiniStore2
    @State private var selectedAudioID: UUID?

    var body: some View {
        VStack {
            // V1: if-let action, no state write
            Button(action: {
                if let a = store.importAudio() {
                    _ = a.id
                }
            }) { Text("V1") }
            .buttonStyle(.bordered)

            // V2: state write, no if-let
            Button(action: {
                let a = store.importAudio()
                selectedAudioID = a?.id
            }) { Text("V2") }
            .buttonStyle(.bordered)

            // V3: simple state write only
            Button(action: { selectedAudioID = nil }) { Text("V3") }
            .buttonStyle(.bordered)

            // V4: method reference
            Button(action: saveAlarm) { Text("V4") }
            .buttonStyle(.borderedProminent)

            // V5: explicit self method call
            Button(action: { self.saveAlarm() }) { Text("V5") }
            .buttonStyle(.borderedProminent)
        }
    }

    private func saveAlarm() {
        store.addAlarm()
    }
}

print("OK")
