import SwiftUI

enum MonochromeTheme {
    static let background = LinearGradient(
        colors: [
            Color.black,
            Color(white: 0.08)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let cardBackground = Color.white.opacity(0.055)
    static let cardBorder = Color.white.opacity(0.16)
    static let secondaryText = Color.white.opacity(0.64)
    static let tertiaryText = Color.white.opacity(0.4)
    static let heatmapBase = Color.white.opacity(0.06)
}
