import SwiftUI

struct SummaryCardsView: View {
    let todaySnapshot: DayMetricsSnapshot
    let currentStreak: Int
    let bestStreak: Int
    let bestRunSeconds: Double
    let qualifyingDays: Int
    let perfectDays: Int
    let heatmapDays: [HeatmapDay]

    var body: some View {
        VStack(spacing: 16) {
            SummaryCard(title: "Today") {
                HStack(spacing: 14) {
                    MetricBlock(title: "Verified Today", value: DurationFormatter.statString(seconds: todaySnapshot.totalVerifiedSeconds))
                    Divider()
                        .overlay(Color.white.opacity(0.1))
                    MetricBlock(title: "Breaks Today", value: "\(todaySnapshot.breakCount)")
                }
            }

            SummaryCard(title: "Streaks") {
                HStack(spacing: 14) {
                    MetricBlock(title: "Current Streak", value: "\(currentStreak)")
                    Divider()
                        .overlay(Color.white.opacity(0.1))
                    MetricBlock(title: "Best Streak", value: "\(bestStreak)")
                }
            }

            SummaryCard(title: "Records") {
                HStack(alignment: .top, spacing: 14) {
                    MetricBlock(title: "Best Run", value: DurationFormatter.statString(seconds: bestRunSeconds))
                    Divider()
                        .overlay(Color.white.opacity(0.1))
                    MetricBlock(title: "Qualifying Days", value: "\(qualifyingDays)")
                    Divider()
                        .overlay(Color.white.opacity(0.1))
                    MetricBlock(title: "Perfect Days", value: "\(perfectDays)")
                }
            }

            SummaryCard(title: "Heatmap") {
                VStack(alignment: .leading, spacing: 14) {
                    HeatmapView(
                        days: heatmapDays,
                        selectedDate: .constant(nil),
                        cellSize: 10,
                        spacing: 4,
                        interactive: false
                    )

                    Text("Last 28 days. Brighter cells mean more verified grayscale time.")
                        .font(.system(size: 12, weight: .medium, design: .serif))
                        .foregroundStyle(MonochromeTheme.tertiaryText)
                }
            }
        }
    }
}

private struct SummaryCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .serif))
                .foregroundStyle(MonochromeTheme.secondaryText)
                .textCase(.uppercase)
                .tracking(1.3)

            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(MonochromeTheme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(MonochromeTheme.cardBorder, lineWidth: 1)
        )
    }
}

private struct MetricBlock: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .medium, design: .serif))
                .foregroundStyle(MonochromeTheme.tertiaryText)
                .textCase(.uppercase)
                .tracking(1.2)

            Text(value)
                .font(.system(size: 24, weight: .light, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
