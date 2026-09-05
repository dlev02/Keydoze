import SwiftUI
import KeydozeCore

/// Local vector artwork: a resting keycap and trackpad. No screen/input capture.
struct DeviceArtwork: View {
    let scope: InputScope
    let palette: KeydozePalette
    let highContrast: Bool
    let reduceMotion: Bool

    var body: some View {
        ZStack {
            Ellipse().fill(palette.accent.opacity(palette.dark ? 0.08 : 0.07))
                .frame(width: 224, height: 70).blur(radius: 21).offset(y: 33)
            trackpad.rotationEffect(.degrees(10)).offset(x: 61, y: scope.pointing || reduceMotion ? -8 : -4)
            keycap.rotationEffect(.degrees(-11)).offset(x: -36, y: scope.keyboard || reduceMotion ? 4 : 8)
            Image(systemName: "sparkle").font(.system(size: 17, weight: .medium))
                .foregroundStyle(palette.accent.opacity(0.8)).offset(x: 104, y: -43)
        }.frame(width: 280, height: 130).accessibilityHidden(true)
    }

    private var keycap: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 19).fill(palette.keySide)
                .frame(width: 115, height: 88).offset(y: 9)
                .shadow(color: .black.opacity(palette.dark ? 0.27 : 0.12), radius: 10, x: 0, y: 8)
            RoundedRectangle(cornerRadius: 19)
                .fill(LinearGradient(colors: [palette.keyTop, palette.keyTop.opacity(0.82)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(RoundedRectangle(cornerRadius: 19).strokeBorder(.white.opacity(palette.dark ? 0.22 : 0.95), lineWidth: 1))
                .overlay(RoundedRectangle(cornerRadius: 19).strokeBorder(palette.accent.opacity(highContrast ? 0.7 : 0.18), lineWidth: highContrast ? 2 : 0.5))
                .frame(width: 115, height: 88)
            VStack(spacing: 8) {
                Image(systemName: "pause.fill").font(.system(size: 29, weight: .medium))
                Image(systemName: "keyboard").font(.system(size: 13, weight: .medium))
            }.foregroundStyle(scope.keyboard ? palette.accent : .secondary.opacity(0.5))
        }
        .rotation3DEffect(.degrees(15), axis: (x: 1, y: 0, z: 0), perspective: 0.3)
    }

    private var trackpad: some View {
        RoundedRectangle(cornerRadius: 15)
            .fill(LinearGradient(colors: [palette.surface, palette.keyTop], startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(RoundedRectangle(cornerRadius: 15).strokeBorder(scope.pointing ? palette.accent.opacity(highContrast ? 0.8 : 0.35) : palette.edge, lineWidth: highContrast ? 2 : 1))
            .overlay(alignment: .bottom) {
                Capsule().fill(scope.pointing ? palette.accent.opacity(0.6) : palette.edge)
                    .frame(width: 25, height: 2).padding(.bottom, 12)
            }
            .frame(width: 87, height: 97)
            .shadow(color: .black.opacity(palette.dark ? 0.24 : 0.08), radius: 8, x: 0, y: 6)
            .rotation3DEffect(.degrees(15), axis: (x: 1, y: 0, z: 0), perspective: 0.3)
    }
}
