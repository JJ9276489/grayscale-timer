import SwiftData
import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var trackingManager: GrayscaleTrackingManager
    @Query(sort: \RunRecord.startTime, order: .forward) private var runs: [RunRecord]
    @Query(sort: \DaySummary.date, order: .forward) private var summaries: [DaySummary]

    @State private var selectedDate = Calendar.autoupdatingCurrent.startOfDay(for: .now)

    var body: some View {
        ScrollView {
            TimelineView(.periodic(from: .now, by: trackingManager.activeRun == nil ? 300 : 60)) { timeline in
                let now = timeline.date
                let calendar = trackingManager.calendar
                let heatmapDays = MetricsService.heatmapData(
                    summaries: summaries,
                    runs: runs,
                    calendar: calendar,
                    now: now,
                    dayCount: AppConfig.heatmapDayCount
                )
                let daySnapshot = MetricsService.daySnapshot(
                    for: selectedDate,
                    runs: runs,
                    calendar: calendar,
                    now: now,
                    includeActive: true
                )

                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Last 90 Days")
                            .font(.system(size: 28, weight: .light, design: .serif))
                            .foregroundStyle(.white)

                        Text("Tap any day for verified time, breaks, and longest uninterrupted run.")
                            .font(.system(size: 14, weight: .medium, design: .serif))
                            .foregroundStyle(MonochromeTheme.secondaryText)
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        HeatmapView(
                            days: heatmapDays,
                            selectedDate: Binding(
                                get: { selectedDate },
                                set: { newValue in
                                    if let newValue {
                                        selectedDate = newValue
                                    }
                                }
                            )
                        )

                        Text("Perfect days are outlined. Qualifying days are the brightest cells.")
                            .font(.system(size: 12, weight: .medium, design: .serif))
                            .foregroundStyle(MonochromeTheme.tertiaryText)
                    }
                    .padding(22)
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(MonochromeTheme.cardBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(MonochromeTheme.cardBorder, lineWidth: 1)
                    )

                    SelectedDayCard(snapshot: daySnapshot, date: selectedDate)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 30)
            }
        }
        .scrollIndicators(.hidden)
        .background(MonochromeTheme.background.ignoresSafeArea())
        .navigationTitle("History")
        .toolbarTitleDisplayMode(.inline)
    }
}

private struct SelectedDayCard: View {
    let snapshot: DayMetricsSnapshot
    let date: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(date, format: .dateTime.month(.wide).day().year())
                .font(.system(size: 22, weight: .light, design: .serif))
                .foregroundStyle(.white)

            HStack(spacing: 10) {
                StatusChip(text: snapshot.qualified ? "Qualified" : "Below Threshold")
                StatusChip(text: snapshot.perfect ? "Perfect" : "Has Breaks")
            }

            VStack(spacing: 14) {
                DetailRow(title: "Verified Grayscale", value: DurationFormatter.statString(seconds: snapshot.totalVerifiedSeconds))
                DetailRow(title: "Breaks", value: "\(snapshot.breakCount)")
                DetailRow(title: "Longest Run", value: DurationFormatter.statString(seconds: snapshot.longestRunSeconds))
            }
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

private struct DetailRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 14, weight: .medium, design: .serif))
                .foregroundStyle(MonochromeTheme.secondaryText)

            Spacer(minLength: 12)

            Text(value)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
        }
    }
}

private struct StatusChip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold, design: .serif))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.08))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
            )
    }
}
