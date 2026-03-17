import SwiftUI

struct RunTimerView: View {
    let activeRun: RunRecord?
    let isGrayscaleActive: Bool
    let currentOffStartTime: Date?
    let stateText: String
    let supportingText: String
    let referenceDate: Date

    @State private var animateSurface = false

    private var displaySeconds: Double {
        if isGrayscaleActive, let activeRun {
            return max(0, referenceDate.timeIntervalSince(activeRun.startTime))
        }

        if let currentOffStartTime {
            return max(0, referenceDate.timeIntervalSince(currentOffStartTime))
        }

        return 0
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(MonochromeTheme.liveBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .stroke(MonochromeTheme.liveBorder, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.5), radius: 30, x: 0, y: 24)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(isGrayscaleActive ? 0.18 : 0.09),
                            Color.white.opacity(0.04),
                            .clear
                        ],
                        center: .center,
                        startRadius: 10,
                        endRadius: 170
                    )
                )
                .frame(width: 280, height: 280)
                .blur(radius: 12)
                .scaleEffect(animateSurface ? 1.02 : 0.97)

            Circle()
                .strokeBorder(
                    AngularGradient(
                        colors: [
                            Color.white.opacity(isGrayscaleActive ? 0.55 : 0.22),
                            .clear,
                            Color.white.opacity(0.18),
                            .clear
                        ],
                        center: .center
                    ),
                    lineWidth: 1.2
                )
                .frame(width: 288, height: 288)
                .rotationEffect(.degrees(animateSurface ? 8 : -5))
                .opacity(isGrayscaleActive ? 1 : 0.68)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.08),
                            Color.white.opacity(0.02),
                            Color.black.opacity(0.28)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 220, height: 220)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.09), lineWidth: 1)
                )

            VStack(spacing: 14) {
                Text(DurationFormatter.clockString(seconds: displaySeconds))
                    .font(.system(size: 66, weight: .ultraLight, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.52)
                    .foregroundStyle(.white)

                Text(stateText)
                    .font(.system(size: 20, weight: .medium, design: .serif))
                    .foregroundStyle(.white.opacity(isGrayscaleActive ? 0.96 : 0.88))

                Text(supportingText)
                    .font(.system(size: 12, weight: .medium, design: .serif))
                    .foregroundStyle(MonochromeTheme.secondaryText)
                    .tracking(0.2)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 46)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 400)
        .onAppear {
            guard !animateSurface else { return }
            withAnimation(.easeInOut(duration: 5.8).repeatForever(autoreverses: true)) {
                animateSurface = true
            }
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.88), value: isGrayscaleActive)
        .animation(.spring(response: 0.42, dampingFraction: 0.88), value: stateText)
    }
}

#Preview("Run Timer - Active") {
    RunTimerView(
        activeRun: RunRecord(startTime: .now.addingTimeInterval(-14_400), isActive: true),
        isGrayscaleActive: true,
        currentOffStartTime: nil,
        stateText: "Line intact",
        supportingText: "Verified uninterrupted grayscale time",
        referenceDate: .now
    )
    .padding(20)
    .background(MonochromeTheme.background)
    .preferredColorScheme(.dark)
}

#Preview("Run Timer - Off") {
    RunTimerView(
        activeRun: nil,
        isGrayscaleActive: false,
        currentOffStartTime: .now.addingTimeInterval(-2_100),
        stateText: "Break detected",
        supportingText: "Use Side Button Triple-Click",
        referenceDate: .now
    )
    .padding(20)
    .background(MonochromeTheme.background)
    .preferredColorScheme(.dark)
}
