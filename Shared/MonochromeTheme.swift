import SwiftUI

enum MonochromeTheme {
    static let background = LinearGradient(
        colors: [
            Color(white: 0.015),
            Color(white: 0.04),
            Color.black
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let ambientGlow = RadialGradient(
        colors: [
            Color.white.opacity(0.07),
            Color.white.opacity(0.015),
            .clear
        ],
        center: .top,
        startRadius: 10,
        endRadius: 340
    )

    static let cardBackground = LinearGradient(
        colors: [
            Color.white.opacity(0.085),
            Color.white.opacity(0.045),
            Color.white.opacity(0.02)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let liveBackground = LinearGradient(
        colors: [
            Color.white.opacity(0.13),
            Color.white.opacity(0.065),
            Color.black.opacity(0.4)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let cardBorder = Color.white.opacity(0.13)
    static let liveBorder = Color.white.opacity(0.2)
    static let highlight = Color.white.opacity(0.82)
    static let secondaryText = Color.white.opacity(0.64)
    static let tertiaryText = Color.white.opacity(0.4)
    static let heatmapBase = Color.white.opacity(0.06)
}
