import SwiftUI
import AppKit

final class MiniStoreW: ObservableObject {
    func addAlarm() {}
}

// V12: method reference + BorderedButtonStyle explicit
struct V12View: View {
    @EnvironmentObject var store: MiniStoreW
    var body: some View {
        Button(action: saveAlarm) { Text("Save") }
        .buttonStyle(BorderedButtonStyle())
    }
    private func saveAlarm() { store.addAlarm() }
}

// V13: method reference + ProminentButtonStyle explicit (may not exist)
struct V13View: View {
    @EnvironmentObject var store: MiniStoreW
    var body: some View {
        Button(action: saveAlarm) { Text("Save") }
        .buttonStyle(ProminentButtonStyle())
    }
    private func saveAlarm() { store.addAlarm() }
}

// V14: method reference + .prominent shorthand
struct V14View: View {
    @EnvironmentObject var store: MiniStoreW
    var body: some View {
        Button(action: saveAlarm) { Text("Save") }
        .buttonStyle(.prominent)
    }
    private func saveAlarm() { store.addAlarm() }
}

struct Probe7Root: View {
    var body: some View {
        VStack { V12View(); V13View(); V14View() }
    }
}

print("OK")
