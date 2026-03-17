import SwiftData
import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var trackingManager: GrayscaleTrackingManager
    @Query(sort: \RunRecord.startTime, order: .forward) private var runs: [RunRecord]
    @Query(sort: \DaySummary.date, order: .forward) private var summaries: [DaySummary]

    var body: some View {
        ScrollView {
            TimelineView(.periodic(from: .now, by: trackingManager.activeRun == nil ? 60 : 1)) { timeline in
                let now = timeline.date
                let calendar = trackingManager.calendar
                let today = calendar.startOfDay(for: now)
                let todaySnapshot = MetricsService.daySnapshot(
                    for: today,
                    runs: runs,
                    calendar: calendar,
                    now: now,
                    includeActive: true
                )
                let mergedSnapshots = MetricsService.mergedDaySnapshots(
                    summaries: summaries,
                    runs: runs,
                    calendar: calendar,
                    now: now
                )
                let heatmapDays = MetricsService.heatmapData(
                    summaries: summaries,
                    runs: runs,
                    calendar: calendar,
                    now: now,
                    dayCount: 28
                )

                VStack(alignment: .leading, spacing: 18) {
                    RunTimerView(
                        activeRun: trackingManager.activeRun,
                        isGrayscaleActive: trackingManager.isGrayscaleEnabled,
                        referenceDate: now
                    )

                    SummaryCardsView(
                        todaySnapshot: todaySnapshot,
                        currentStreak: MetricsService.currentStreak(from: mergedSnapshots, calendar: calendar, today: now),
                        bestStreak: MetricsService.bestStreak(from: mergedSnapshots, calendar: calendar),
                        bestRunSeconds: MetricsService.bestRun(from: runs, now: now),
                        qualifyingDays: MetricsService.qualifyingDayCount(from: mergedSnapshots),
                        perfectDays: MetricsService.perfectDayCount(from: mergedSnapshots),
                        heatmapDays: heatmapDays
                    )
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 30)
            }
        }
        .scrollIndicators(.hidden)
        .background(MonochromeTheme.background.ignoresSafeArea())
        .navigationTitle("Grayscale Timer")
        .toolbarTitleDisplayMode(.inline)
    }
}
