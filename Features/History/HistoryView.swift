import SwiftData
import SwiftUI

private enum HistoryRange: Int, CaseIterable, Identifiable {
    case days28 = 28
    case days90 = 90

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .days28:
            return "28 Days"
        case .days90:
            return "90 Days"
        }
    }
}

struct HistoryView: View {
    @EnvironmentObject private var trackingManager: GrayscaleTrackingManager
    @Query(sort: \RunRecord.startTime, order: .forward) private var runs: [RunRecord]
    @Query(sort: \DaySummary.date, order: .forward) private var summaries: [DaySummary]

    @State private var selectedDate = Calendar.autoupdatingCurrent.startOfDay(for: .now)
    @State private var selectedRange: HistoryRange = .days90

    var body: some View {
        ScrollView {
            TimelineView(.periodic(from: .now, by: trackingManager.activeRun == nil ? 300 : 60)) { timeline in
                let now = timeline.date
                let calendar = trackingManager.calendar
                let goalSettings = GoalSettingsStore.load()
                let heatmapDays = MetricsService.heatmapData(
                    summaries: summaries,
                    runs: runs,
                    calendar: calendar,
                    now: now,
                    dayCount: selectedRange.rawValue,
                    goalSettings: goalSettings
                )
                let daySnapshot = MetricsService.daySnapshot(
                    for: selectedDate,
                    runs: runs,
                    calendar: calendar,
                    now: now,
                    includeActive: true,
                    goalSettings: goalSettings
                )
                let weeklyAggregates = MetricsService.weeklyAggregates(
                    summaries: summaries,
                    runs: runs,
                    calendar: calendar,
                    now: now,
                    goalSettings: goalSettings
                )
                let thisWeekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? calendar.startOfDay(for: now)
                let lastWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: thisWeekStart) ?? thisWeekStart
                let thisWeek = weeklyAggregates.first(where: { calendar.isDate($0.startDate, inSameDayAs: thisWeekStart) })
                let lastWeek = weeklyAggregates.first(where: { calendar.isDate($0.startDate, inSameDayAs: lastWeekStart) })
                let bestWeek = weeklyAggregates.max { $0.averageGrayRate < $1.averageGrayRate }

                VStack(alignment: .leading, spacing: 20) {
                    Picker("Range", selection: $selectedRange) {
                        ForEach(HistoryRange.allCases) { range in
                            Text(range.title).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)

                    WeeklySummaryStrip(
                        thisWeek: thisWeek,
                        lastWeek: lastWeek,
                        bestWeek: bestWeek,
                        perfectDaysThisWeek: thisWeek?.perfectDayCount ?? 0
                    )

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

                        Text(selectedRange == .days28 ? "Last 28 days. Perfect days are outlined." : "Last 90 days. Perfect days are outlined.")
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
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.26), radius: 18, x: 0, y: 14)

                    ZStack {
                        DayDetailView(snapshot: daySnapshot, date: selectedDate, goalSettings: goalSettings)
                            .id(daySnapshot.id)
                            .transition(.opacity.combined(with: .scale(scale: 0.985)))
                    }
                    .animation(.spring(response: 0.32, dampingFraction: 0.86), value: selectedDate)
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

private struct WeeklySummaryStrip: View {
    let thisWeek: WeeklyAggregate?
    let lastWeek: WeeklyAggregate?
    let bestWeek: WeeklyAggregate?
    let perfectDaysThisWeek: Int

    var body: some View {
        HStack(spacing: 12) {
            WeeklyMetric(title: "This Week", value: percentString(thisWeek?.averageGrayRate ?? 0))
            WeeklyMetric(title: "Last Week", value: percentString(lastWeek?.averageGrayRate ?? 0))
            WeeklyMetric(title: "Best Week", value: percentString(bestWeek?.averageGrayRate ?? 0))
            WeeklyMetric(title: "Perfect Days", value: "\(perfectDaysThisWeek)")
        }
    }

    private func percentString(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }
}

private struct WeeklyMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .medium, design: .serif))
                .foregroundStyle(MonochromeTheme.tertiaryText)
                .textCase(.uppercase)
                .tracking(1.1)

            Text(value)
                .font(.system(size: 18, weight: .light, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(MonochromeTheme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.22), radius: 12, x: 0, y: 10)
    }
}

#Preview("History Detail - Qualifying") {
    DayDetailView(
        snapshot: DayMetricsSnapshot(
            date: .now,
            totalVerifiedSeconds: 68_400,
            breakCount: 1,
            longestRunSeconds: 31_200,
            relapseSeconds: 2_400,
            eligibleSeconds: 86_400,
            grayRate: 0.79,
            isQualifying: true,
            isStrong: false,
            isPerfect: false,
            perfectIntact: false,
            status: .qualifying
        ),
        date: .now,
        goalSettings: GoalSettings.default
    )
    .padding(20)
    .background(MonochromeTheme.background)
    .preferredColorScheme(.dark)
}

#Preview("History Detail - Strong") {
    DayDetailView(
        snapshot: DayMetricsSnapshot(
            date: .now,
            totalVerifiedSeconds: 78_000,
            breakCount: 2,
            longestRunSeconds: 32_400,
            relapseSeconds: 2_100,
            eligibleSeconds: 86_400,
            grayRate: 0.90,
            isQualifying: true,
            isStrong: true,
            isPerfect: false,
            perfectIntact: false,
            status: .strong
        ),
        date: .now,
        goalSettings: GoalSettings.default
    )
    .padding(20)
    .background(MonochromeTheme.background)
    .preferredColorScheme(.dark)
}

#Preview("History Detail - Perfect") {
    DayDetailView(
        snapshot: DayMetricsSnapshot(
            date: .now,
            totalVerifiedSeconds: 80_000,
            breakCount: 0,
            longestRunSeconds: 80_000,
            relapseSeconds: 0,
            eligibleSeconds: 86_400,
            grayRate: 0.93,
            isQualifying: true,
            isStrong: true,
            isPerfect: true,
            perfectIntact: true,
            status: .perfect
        ),
        date: .now,
        goalSettings: GoalSettings.default
    )
    .padding(20)
    .background(MonochromeTheme.background)
    .preferredColorScheme(.dark)
}

#Preview("History Detail - Missed") {
    DayDetailView(
        snapshot: DayMetricsSnapshot(
            date: .now,
            totalVerifiedSeconds: 18_000,
            breakCount: 3,
            longestRunSeconds: 7_200,
            relapseSeconds: 14_400,
            eligibleSeconds: 86_400,
            grayRate: 0.21,
            isQualifying: false,
            isStrong: false,
            isPerfect: false,
            perfectIntact: false,
            status: .missed
        ),
        date: .now,
        goalSettings: GoalSettings.default
    )
    .padding(20)
    .background(MonochromeTheme.background)
    .preferredColorScheme(.dark)
}
