import SwiftUI

struct SummaryCardsView: View {
    let todaySnapshot: DayMetricsSnapshot
    let todayFooterText: String?
    let currentQualifyingStreak: Int
    let bestQualifyingStreak: Int
    let bestDaySeconds: Double
    let sevenDayAverageRate: Double
    let onTodayTap: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Button(action: onTodayTap) {
                TodaySurface(
                    grayRateText: percentString(todaySnapshot.grayRate),
                    verifiedText: DurationFormatter.statString(seconds: todaySnapshot.totalVerifiedSeconds),
                    breaksText: "\(todaySnapshot.breakCount)",
                    relapseText: DurationFormatter.statString(seconds: todaySnapshot.relapseSeconds),
                    footerText: todayFooterText
                )
            }
            .buttonStyle(TactileSurfaceButtonStyle(cornerRadius: 30))

            ProgressionSurface(
                currentStreak: "\(currentQualifyingStreak)",
                bestStreak: "\(bestQualifyingStreak)",
                bestDay: DurationFormatter.statString(seconds: bestDaySeconds),
                sevenDayAverage: percentString(sevenDayAverageRate)
            )
        }
    }

    private func percentString(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }
}

private struct TodaySurface: View {
    let grayRateText: String
    let verifiedText: String
    let breaksText: String
    let relapseText: String
    let footerText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .bottom, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(grayRateText)
                        .font(.system(size: 56, weight: .ultraLight, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)

                    Text("Gray Rate Today")
                        .font(.system(size: 12, weight: .medium, design: .serif))
                        .foregroundStyle(MonochromeTheme.secondaryText)
                        .tracking(0.3)
                }

                Spacer(minLength: 0)

                VStack(alignment: .leading, spacing: 12) {
                    InlineMetric(title: "Verified", value: verifiedText)
                    InlineMetric(title: "Breaks", value: breaksText)
                    InlineMetric(title: "Relapse", value: relapseText)
                }
            }

            if let footerText {
                Text(footerText)
                    .font(.system(size: 13, weight: .medium, design: .serif))
                    .foregroundStyle(MonochromeTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(26)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(MonochromeTheme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.32), radius: 22, x: 0, y: 16)
    }
}

private struct ProgressionSurface: View {
    let currentStreak: String
    let bestStreak: String
    let bestDay: String
    let sevenDayAverage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Progression")
                .font(.system(size: 12, weight: .medium, design: .serif))
                .foregroundStyle(MonochromeTheme.secondaryText)
                .tracking(0.5)

            HStack(spacing: 18) {
                MetricBlock(title: "Current Streak", value: currentStreak, prominence: .primary)
                MetricBlock(title: "Best Streak", value: bestStreak, prominence: .primary)
            }

            Divider()
                .overlay(Color.white.opacity(0.07))

            HStack(spacing: 18) {
                MetricBlock(title: "Best Day", value: bestDay, prominence: .secondary)
                MetricBlock(title: "7-Day Average", value: sevenDayAverage, prominence: .secondary)
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(MonochromeTheme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.24), radius: 18, x: 0, y: 14)
        // Phone use split stays omitted until the app has a reliable system-backed usage source.
    }
}

private struct MetricBlock: View {
    enum Prominence {
        case primary
        case secondary
    }

    let title: String
    let value: String
    let prominence: Prominence

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 10, weight: .medium, design: .serif))
                .foregroundStyle(MonochromeTheme.tertiaryText)
                .tracking(0.3)

            Text(value)
                .font(.system(size: prominence == .primary ? 30 : 20, weight: .light, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(prominence == .primary ? 1 : 0.9))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct InlineMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10, weight: .medium, design: .serif))
                .foregroundStyle(MonochromeTheme.tertiaryText)

            Text(value)
                .font(.system(size: 18, weight: .light, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.92))
        }
    }
}

#Preview("Home Cards") {
    ScrollView {
        SummaryCardsView(
            todaySnapshot: DayMetricsSnapshot(
                date: .now,
                totalVerifiedSeconds: 42_000,
                breakCount: 1,
                longestRunSeconds: 18_000,
                relapseSeconds: 3_600,
                eligibleSeconds: 54_000,
                grayRate: 0.78,
                isQualifying: true,
                isStrong: false,
                isPerfect: false,
                perfectIntact: false,
                status: .qualifying
            ),
            todayFooterText: "Return now to recover pace.",
            currentQualifyingStreak: 5,
            bestQualifyingStreak: 11,
            bestDaySeconds: 74_700,
            sevenDayAverageRate: 0.78,
            onTodayTap: {}
        )
        .padding(20)
    }
    .background(MonochromeTheme.background)
    .preferredColorScheme(.dark)
}
