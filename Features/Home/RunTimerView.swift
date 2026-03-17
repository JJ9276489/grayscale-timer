import SwiftUI

struct RunTimerView: View {
    let activeRun: RunRecord?
    let isGrayscaleActive: Bool
    let referenceDate: Date

    private var displaySeconds: Double {
        guard isGrayscaleActive, let activeRun else { return 0 }
        return referenceDate.timeIntervalSince(activeRun.startTime)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(isGrayscaleActive ? "Current Run" : "Grayscale Off")
                .font(.system(size: 13, weight: .semibold, design: .serif))
                .foregroundStyle(MonochromeTheme.secondaryText)
                .textCase(.uppercase)
                .tracking(1.4)

            Text(DurationFormatter.clockString(seconds: displaySeconds))
                .font(.system(size: 54, weight: .ultraLight, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .foregroundStyle(.white)

            Text(isGrayscaleActive ? "Verified uninterrupted grayscale time." : "Tracking resumes the moment iOS reports grayscale enabled.")
                .font(.system(size: 14, weight: .medium, design: .serif))
                .foregroundStyle(MonochromeTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(28)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(isGrayscaleActive ? 0.12 : 0.07),
                            Color.white.opacity(0.03)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.16), lineWidth: 1)
        )
    }
}
