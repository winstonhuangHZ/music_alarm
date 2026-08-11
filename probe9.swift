import SwiftUI

// A: monospacedDigit alone after font
struct P9_A: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 20, weight: .semibold, design: .rounded))
            .monospacedDigit()
    }
}

// B: monospacedDigit + foregroundColor(.secondary)
struct P9_B: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 20, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .foregroundColor(.secondary)
    }
}

// C: monospacedDigit + ternary foregroundColor (mirrors AlarmRowView)
struct P9_C: View {
    let text: String
    @State private var enabled = false
    var body: some View {
        Text(text)
            .font(.system(size: 20, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .foregroundColor(enabled ? .primary : .secondary)
    }
}

// D: no monospacedDigit, font + foregroundColor(.secondary)
struct P9_D: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 20, weight: .semibold, design: .rounded))
            .foregroundColor(.secondary)
    }
}

// E: monospacedDigit + opacity
struct P9_E: View {
    let text: String
    @State private var appeared = false
    var body: some View {
        Text(text)
            .font(.system(size: 20, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .opacity(appeared ? 1 : 0)
    }
}

// F: monospacedDigit with plain system font (no design), like maybe working elsewhere
struct P9_F: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 20, weight: .semibold))
            .monospacedDigit()
    }
}
