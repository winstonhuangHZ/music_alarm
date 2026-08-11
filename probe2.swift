import SwiftUI
import AppKit

enum RepeatType: String, CaseIterable {
    case once = "Once"
    case daily = "Daily"
    case weekdays = "Weekdays"
}

struct Probe2View: View {
    @State private var selInt = 0
    @State private var selEnum: RepeatType = .once

    var body: some View {
        VStack {
            // Variant A: Int selection, explicit label + explicit SegmentedPickerStyle()
            Picker(selection: $selInt, label: Text("A")) {
                Text("One").tag(0)
                Text("Two").tag(1)
            }
            .pickerStyle(SegmentedPickerStyle())

            // Variant B: enum selection, explicit label + explicit SegmentedPickerStyle()
            Picker(selection: $selEnum, label: Text("B")) {
                Text("Once").tag(RepeatType.once)
                Text("Daily").tag(RepeatType.daily)
                Text("Weekdays").tag(RepeatType.weekdays)
            }
            .pickerStyle(SegmentedPickerStyle())
        }
    }
}

print("OK")
