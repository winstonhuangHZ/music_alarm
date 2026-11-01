import SwiftUI
import AppKit

enum ThemeVisualState {
    case idle
    case upcoming
    case paused
    case ringing
    case confirming
}

struct AppThemePalette {
    let background: Color
    let surface: Color
    let primaryText: Color
    let secondaryText: Color
    let accent: Color
    let warning: Color
    let danger: Color
    let success: Color
    let flowColors: [Color]
    let colorScheme: ColorScheme?

    static func palette(for choice: ThemeChoice) -> AppThemePalette {
        switch choice {
        case .system:
            return AppThemePalette(background: Color(NSColor.windowBackgroundColor),
                                   surface: Color(NSColor.controlBackgroundColor),
                                   primaryText: .primary,
                                   secondaryText: .secondary,
                                   accent: Color.accentColor,
                                   warning: .orange,
                                   danger: .red,
                                   success: .green,
                                   flowColors: [.blue, .purple, .orange],
                                   colorScheme: nil)
        case .light:
            return AppThemePalette(background: Color(hex: "F7F7FA"),
                                   surface: Color(hex: "FFFFFF"),
                                   primaryText: Color(hex: "20202A"),
                                   secondaryText: Color(hex: "666675"),
                                   accent: Color(hex: "7C3AED"),
                                   warning: Color(hex: "D97706"),
                                   danger: Color(hex: "DC2626"),
                                   success: Color(hex: "059669"),
                                   flowColors: [.purple, .orange, .pink],
                                   colorScheme: .light)
        case .dark:
            return AppThemePalette(background: Color(hex: "11121A"),
                                   surface: Color(hex: "1D1F2B"),
                                   primaryText: Color(hex: "F5F5F7"),
                                   secondaryText: Color(hex: "A8AAB8"),
                                   accent: Color(hex: "A78BFA"),
                                   warning: Color(hex: "F59E0B"),
                                   danger: Color(hex: "FB7185"),
                                   success: Color(hex: "6EE7B7"),
                                   flowColors: [Color(hex: "6366F1"), Color(hex: "A855F7"), Color(hex: "3B82F6")],
                                   colorScheme: .dark)
        case .dawnFlow:
            return AppThemePalette(background: Color(hex: "171126"),
                                   surface: Color(hex: "27183B"),
                                   primaryText: Color(hex: "FFF7ED"),
                                   secondaryText: Color(hex: "D8C9E8"),
                                   accent: Color(hex: "FF9F1C"),
                                   warning: Color(hex: "FFB000"),
                                   danger: Color(hex: "FF4D5A"),
                                   success: Color(hex: "64E6A6"),
                                   flowColors: [Color(hex: "FF8A00"), Color(hex: "FF3D71"), Color(hex: "7A3DF0"), Color(hex: "2D6CDF")],
                                   colorScheme: .dark)
        case .dracula:
            return AppThemePalette(background: Color(hex: "282A36"),
                                   surface: Color(hex: "44475A"),
                                   primaryText: Color(hex: "F8F8F2"),
                                   secondaryText: Color(hex: "BFBFB3"),
                                   accent: Color(hex: "BD93F9"),
                                   warning: Color(hex: "FFB86C"),
                                   danger: Color(hex: "FF5555"),
                                   success: Color(hex: "50FA7B"),
                                   flowColors: [Color(hex: "BD93F9"), Color(hex: "FF79C6"), Color(hex: "FFB86C")],
                                   colorScheme: .dark)
        case .nord:
            return AppThemePalette(background: Color(hex: "2E3440"),
                                   surface: Color(hex: "3B4252"),
                                   primaryText: Color(hex: "ECEFF4"),
                                   secondaryText: Color(hex: "D8DEE9"),
                                   accent: Color(hex: "88C0D0"),
                                   warning: Color(hex: "EBCB8B"),
                                   danger: Color(hex: "BF616A"),
                                   success: Color(hex: "A3BE8C"),
                                   flowColors: [Color(hex: "5E81AC"), Color(hex: "81A1C1"), Color(hex: "88C0D0")],
                                   colorScheme: .dark)
        case .catppuccin:
            return AppThemePalette(background: Color(hex: "1E1E2E"),
                                   surface: Color(hex: "313244"),
                                   primaryText: Color(hex: "CDD6F4"),
                                   secondaryText: Color(hex: "A6ADC8"),
                                   accent: Color(hex: "CBA6F7"),
                                   warning: Color(hex: "FAB387"),
                                   danger: Color(hex: "F38BA8"),
                                   success: Color(hex: "A6E3A1"),
                                   flowColors: [Color(hex: "CBA6F7"), Color(hex: "F5C2E7"), Color(hex: "FAB387")],
                                   colorScheme: .dark)
        }
    }

    func colors(for state: ThemeVisualState) -> [Color] {
        switch state {
        case .idle: return flowColors.map { $0.opacity(0.58) }
        case .upcoming: return [accent, warning, flowColors.last ?? accent]
        case .paused: return [secondaryText, background, surface]
        case .ringing: return [danger, accent, flowColors.first ?? danger]
        case .confirming: return [success, accent, flowColors.last ?? success]
        }
    }
}

struct ThemeBackdrop: View {
    let choice: ThemeChoice
    let visualState: ThemeVisualState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var rotation = 0.0

    var body: some View {
        let palette = AppThemePalette.palette(for: choice)
        ZStack {
            palette.background
            AngularGradient(gradient: Gradient(colors: palette.colors(for: visualState)),
                            center: .center,
                            angle: .degrees(rotation))
                .opacity(0.24)
                .blur(radius: 42)
                .scaleEffect(1.25)
            Circle()
                .fill(palette.colors(for: visualState).first?.opacity(0.18) ?? .clear)
                .frame(width: 260, height: 260)
                .blur(radius: 52)
                .offset(x: rotation.truncatingRemainder(dividingBy: 80) - 40,
                        y: -rotation.truncatingRemainder(dividingBy: 110) + 55)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 36).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
        .onChange(of: visualStateKey) { _ in
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.2)) {
                rotation += 18
            }
        }
        .ignoresSafeArea()
    }

    private var visualStateKey: String {
        switch visualState {
        case .idle: return "idle"
        case .upcoming: return "upcoming"
        case .paused: return "paused"
        case .ringing: return "ringing"
        case .confirming: return "confirming"
        }
    }
}

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let red = Double((value >> 16) & 0xFF) / 255
        let green = Double((value >> 8) & 0xFF) / 255
        let blue = Double(value & 0xFF) / 255
        self.init(red: red, green: green, blue: blue)
    }
}
