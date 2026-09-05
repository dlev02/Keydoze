import SwiftUI

/// A small, app-specific palette. Content remains opaque and text uses system semantic
/// styles; separate light/dark values give the utility a warm paper / charcoal character.
struct KeydozePalette {
    let dark: Bool
    var canvas: Color { dark ? Color(red: 0.105, green: 0.12, blue: 0.115) : Color(red: 0.97, green: 0.975, blue: 0.96) }
    var surface: Color { dark ? Color(red: 0.145, green: 0.165, blue: 0.155) : .white }
    var accent: Color { dark ? Color(red: 0.67, green: 0.84, blue: 0.73) : Color(red: 0.18, green: 0.39, blue: 0.29) }
    var edge: Color { dark ? .white.opacity(0.10) : .black.opacity(0.09) }
    var keyTop: Color { dark ? Color(red: 0.29, green: 0.36, blue: 0.32) : Color(red: 0.97, green: 0.99, blue: 0.97) }
    var keySide: Color { dark ? Color(red: 0.13, green: 0.18, blue: 0.15) : Color(red: 0.72, green: 0.79, blue: 0.74) }
}

/// Optical dimensions for this fixed-size instrument are shared instead of treated as
/// platform-wide spacing rules. Native sheets/controls still use their own sizing.
enum KeydozeLayout {
    static let width: CGFloat = 440
    static let height: CGFloat = 510
    static let inset: CGFloat = 32
    static let corner: CGFloat = 14
}

/// A quiet capsule selection with native button focus and keyboard activation.
struct DurationChoiceStyle: ButtonStyle {
    let selected: Bool
    let palette: KeydozePalette
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(selected ? palette.accent : .primary.opacity(0.72))
            .opacity(configuration.isPressed ? 0.65 : 1)
            .contentShape(Capsule())
    }
}

/// Short, non-bouncing motion follows user choices; deadlines never depend on it.
enum KeydozeMotion {
    static let selection: Animation = .smooth(duration: 0.24, extraBounce: 0)
    static let screen: Animation = .smooth(duration: 0.28, extraBounce: 0)
    static let digits: Animation = .easeOut(duration: 0.18)
}
