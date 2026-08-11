import SwiftUI
import AppKit

struct ImportedAudioZ: Identifiable {
    let id = UUID()
    let name: String
}

final class MiniStore3: ObservableObject {
    @discardableResult
    func importAudio() -> ImportedAudioZ? { return nil }
    func addAlarm() {}
}

// V1: if-let action, no state write
struct V1View: View {
    @EnvironmentObject var store: MiniStore3
    var body: some View {
        Button(action: {
            if let a = store.importAudio() {
                _ = a.id
            }
        }) { Text("V1") }
        .buttonStyle(.bordered)
    }
}

// V2: state write, no if-let
struct V2View: View {
    @EnvironmentObject var store: MiniStore3
    @State private var selectedAudioID: UUID?
    var body: some View {
        Button(action: {
            let a = store.importAudio()
            selectedAudioID = a?.id
        }) { Text("V2") }
        .buttonStyle(.bordered)
    }
}

// V3: simple state write only
struct V3View: View {
    @State private var selectedAudioID: UUID?
    var body: some View {
        Button(action: { selectedAudioID = nil }) { Text("V3") }
        .buttonStyle(.bordered)
    }
}

// V4: method reference
struct V4View: View {
    @EnvironmentObject var store: MiniStore3
    var body: some View {
        Button(action: saveAlarm) { Text("V4") }
        .buttonStyle(.borderedProminent)
    }
    private func saveAlarm() { store.addAlarm() }
}

// V5: explicit self method call
struct V5View: View {
    @EnvironmentObject var store: MiniStore3
    var body: some View {
        Button(action: { self.saveAlarm() }) { Text("V5") }
        .buttonStyle(.borderedProminent)
    }
    private func saveAlarm() { store.addAlarm() }
}

// Reference all so they are type-checked
struct Probe5Root: View {
    var body: some View {
        VStack {
            V1View(); V2View(); V3View(); V4View(); V5View()
        }
    }
}

print("OK")
