import SwiftUI

enum LineVisuals {
    static func segmentGradient(isActive: Bool) -> LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(isActive ? 0.96 : 0.36),
                Color.white.opacity(isActive ? 0.34 : 0.14)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

struct LineProgressRail: View {
    let progress: Double
    let isActive: Bool
    var minimumProgress: Double = 0.06

    var body: some View {
        GeometryReader { geometry in
            let clampedProgress = min(max(progress, 0), 1)
            let visibleProgress = max(clampedProgress, minimumProgress)

            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(isActive ? 0.28 : 0.18),
                                    Color.white.opacity(0.05)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * CGFloat(visibleProgress))
                }
        }
        .frame(height: 2)
    }
}

struct LineFractureMark: View {
    let size: CGSize
    let lineWidth: CGFloat
    var backgroundOpacity: Double = 0.78
    var lineOpacity: Double = 0.7

    var body: some View {
        ZStack {
            Capsule(style: .continuous)
                .fill(Color.black.opacity(backgroundOpacity))
                .frame(width: size.width, height: max(4, size.height * 0.24))

            Rectangle()
                .fill(Color.white.opacity(lineOpacity))
                .frame(width: lineWidth, height: size.height * 0.9)
                .rotationEffect(.degrees(26))
            .shadow(color: .black.opacity(0.24), radius: 3, x: 0, y: 0)
        }
    }
}
