import SwiftUI

// A: monospacedDigit + material background (mirrors current AlarmPopupView)
struct P8_A: View {
    let text: String
    @State private var appeared = false
    var body: some View {
        VStack(spacing: 14) {
            Text(text)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(.secondary)
                .opacity(appeared ? 1 : 0)
        }
        .padding(32)
        .frame(width: 460)
        .opacity(appeared ? 1 : 0)
        .scaleEffect(appeared ? 1 : 0.6)
        .background(.ultraThinMaterial)
    }
}

// B: no monospacedDigit, keep material background
struct P8_B: View {
    let text: String
    @State private var appeared = false
    var body: some View {
        VStack(spacing: 14) {
            Text(text)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundColor(.secondary)
                .opacity(appeared ? 1 : 0)
        }
        .padding(32)
        .frame(width: 460)
        .opacity(appeared ? 1 : 0)
        .scaleEffect(appeared ? 1 : 0.6)
        .background(.ultraThinMaterial)
    }
}

// C: keep monospacedDigit, replace material with plain Color background
struct P8_C: View {
    let text: String
    @State private var appeared = false
    var body: some View {
        VStack(spacing: 14) {
            Text(text)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(.secondary)
                .opacity(appeared ? 1 : 0)
        }
        .padding(32)
        .frame(width: 460)
        .opacity(appeared ? 1 : 0)
        .scaleEffect(appeared ? 1 : 0.6)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// D: no monospacedDigit, plain Color background
struct P8_D: View {
    let text: String
    @State private var appeared = false
    var body: some View {
        VStack(spacing: 14) {
            Text(text)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundColor(.secondary)
                .opacity(appeared ? 1 : 0)
        }
        .padding(32)
        .frame(width: 460)
        .opacity(appeared ? 1 : 0)
        .scaleEffect(appeared ? 1 : 0.6)
        .background(Color(NSColor.windowBackgroundColor))
    }
}
