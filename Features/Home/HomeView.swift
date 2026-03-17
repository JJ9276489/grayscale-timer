import SwiftData
import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var trackingManager: GrayscaleTrackingManager
    @AppStorage(GoalSettingsStore.Key.quickReturnMethod) private var quickReturnMethodRawValue = QuickReturnMethod.accessibilityShortcut.rawValue
    @Query(sort: \RunRecord.startTime, order: .forward) private var runs: [RunRecord]
    @Query(sort: \DaySummary.date, order: .forward) private var summaries: [DaySummary]

    var body: some View {
        ScrollView {
            TimelineView(.periodic(from: .now, by: trackingManager.activeRun == nil ? 60 : 1)) { timeline in
                let now = timeline.date
                let calendar = trackingManager.calendar
                let goalSettings = GoalSettingsStore.load()
                let today = calendar.startOfDay(for: now)
                let todaySnapshot = MetricsService.daySnapshot(
                    for: today,
                    runs: runs,
                    calendar: calendar,
                    now: now,
                    includeActive: true,
                    goalSettings: goalSettings
                )
                let mergedSnapshots = MetricsService.mergedDaySnapshots(
                    summaries: summaries,
                    runs: runs,
                    calendar: calendar,
                    now: now,
                    goalSettings: goalSettings
                )
                let trendSummary = MetricsService.trendSummary(
                    summaries: summaries,
                    runs: runs,
                    calendar: calendar,
                    now: now,
                    goalSettings: goalSettings
                )
                let recoverySummary = MetricsService.recoverySummary(from: runs, now: now)
                let todayStatus = MetricsService.todayStatusSummary(
                    for: todaySnapshot,
                    calendar: calendar,
                    now: now,
                    isGrayscaleActive: trackingManager.isGrayscaleEnabled,
                    goalSettings: goalSettings
                )
                let quickReturnMethod = QuickReturnMethod(rawValue: quickReturnMethodRawValue) ?? .accessibilityShortcut
                let activeRunAge = trackingManager.activeRun.map { now.timeIntervalSince($0.startTime) } ?? .infinity
                let heroStateText: String = {
                    if trackingManager.isGrayscaleEnabled {
                        if todaySnapshot.perfectIntact {
                            return "Perfect day intact"
                        }

                        if recoverySummary.latestRecoverySeconds != nil, activeRunAge < 1_800 {
                            return "Recovered"
                        }

                        return "Line intact"
                    }

                    if trackingManager.currentOffStartTime != nil {
                        return "Break detected"
                    }

                    return "Grayscale inactive"
                }()
                let heroSupportingText: String = {
                    if trackingManager.isGrayscaleEnabled {
                        if let latestRecoverySeconds = recoverySummary.latestRecoverySeconds, activeRunAge < 1_800 {
                            return "Latest recovery \(DurationFormatter.statString(seconds: latestRecoverySeconds))"
                        }

                        return "Verified uninterrupted grayscale time"
                    }

                    return quickReturnMethod.homePrompt
                }()

                VStack(alignment: .leading, spacing: 20) {
                    RunTimerView(
                        activeRun: trackingManager.activeRun,
                        isGrayscaleActive: trackingManager.isGrayscaleEnabled,
                        currentOffStartTime: trackingManager.currentOffStartTime,
                        stateText: heroStateText,
                        supportingText: heroSupportingText,
                        referenceDate: now
                    )

                    SummaryCardsView(
                        todaySnapshot: todaySnapshot,
                        todayStatus: todayStatus,
                        currentQualifyingStreak: MetricsService.currentQualifyingStreak(from: mergedSnapshots, calendar: calendar, today: now),
                        bestQualifyingStreak: MetricsService.bestQualifyingStreak(from: mergedSnapshots, calendar: calendar),
                        bestDaySeconds: MetricsService.bestDay(from: mergedSnapshots),
                        sevenDayAverageRate: trendSummary.currentAverageRate
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
