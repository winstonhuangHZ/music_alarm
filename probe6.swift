import SwiftUI
import AppKit

// V6: exact ContentView button pattern (HStack label, trailing modifiers)
struct V6View: View {
    @State private var showAddAlarm = false
    var body: some View {
        Button(action: { showAddAlarm = true }) {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                Text("Add Alarm")
            }
            .font(.headline)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
        }
        .buttonStyle(.borderedProminent)
        .accentColor(.red)
        .controlSize(.large)
    }
}

// V7: simple action, HStack label, .bordered
struct V7View: View {
    @State private var sel: UUID?
    var body: some View {
        Button(action: { sel = nil }) {
            HStack(spacing: 6) {
                Image(systemName: "folder")
                Text("Import Music")
            }
        }
        .buttonStyle(.bordered)
    }
}

// V8: Text label only, .bordered
struct V8View: View {
    var body: some View {
        Button(action: {}) { Text("V8") }
        .buttonStyle(.bordered)
    }
}

// V9: Button("label", action:) form, .bordered
struct V9View: View {
    var body: some View {
        Button("V9", action: {})
        .buttonStyle(.bordered)
    }
}

// V10: explicit BorderedButtonStyle()
struct V10View: View {
    @State private var sel: UUID?
    var body: some View {
        Button(action: {
            if let a = sel {
                _ = a
            }
        }) { Text("V10") }
        .buttonStyle(BorderedButtonStyle())
    }
}

// V11: explicit BorderedProminentButtonStyle()
struct V11View: View {
    @EnvironmentObject var store: MiniStoreZ
    var body: some View {
        Button(action: { self.saveAlarm() }) { Text("V11") }
        .buttonStyle(BorderedProminentButtonStyle())
    }
    private func saveAlarm() { store.addAlarm() }
}

final class MiniStoreZ: ObservableObject {
    func addAlarm() {}
}

struct Probe6Root: View {
    var body: some View {
        VStack { V6View(); V7View(); V8View(); V9View(); V10View(); V11View() }
    }
}

print("OK")
