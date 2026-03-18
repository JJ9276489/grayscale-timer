import SwiftData
import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var trackingManager: GrayscaleTrackingManager
    @AppStorage(GoalSettingsStore.Key.quickReturnMethod) private var quickReturnMethodRawValue = QuickReturnMethod.accessibilityShortcut.rawValue
    @Query(sort: \RunRecord.startTime, order: .forward) private var runs: [RunRecord]
    @Query(sort: \DaySummary.date, order: .forward) private var summaries: [DaySummary]

    @State private var isHeroExpanded = false
    @State private var showTodayDetailSheet = false
    @State private var showHeroOverlay = false
    @State private var heroOverlayDismissTask: Task<Void, Never>?

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
                let dayIsDamaged = todaySnapshot.breakCount > 0
                let heroStateText: String = {
                    if trackingManager.isGrayscaleEnabled {
                        if todaySnapshot.perfectIntact {
                            return "Perfect intact"
                        }

                        if dayIsDamaged {
                            return "Recovered"
                        }

                        return "Line intact"
                    }

                    return "Out of grayscale"
                }()
                let heroSupportingText: String = {
                    if trackingManager.isGrayscaleEnabled {
                        if let latestRecoverySeconds = recoverySummary.latestRecoverySeconds, activeRunAge < 1_800 {
                            return "Latest recovery \(DurationFormatter.statString(seconds: latestRecoverySeconds))"
                        }

                        return "Verified uninterrupted run"
                    }

                    return quickReturnMethod.homePrompt
                }()
                let expandedDetails = HeroExpandedDetails(
                    grayRateText: "\(Int((todaySnapshot.grayRate * 100).rounded()))%",
                    verifiedText: DurationFormatter.statString(seconds: todaySnapshot.totalVerifiedSeconds),
                    breaksText: "\(todaySnapshot.breakCount)",
                    relapseText: DurationFormatter.statString(seconds: todaySnapshot.relapseSeconds)
                )
                let startedReference = trackingManager.isGrayscaleEnabled ? trackingManager.activeRun?.startTime : trackingManager.currentOffStartTime
                let startedText = startedReference?.formatted(date: .omitted, time: .shortened)
                let todayFooterText: String? = {
                    if todaySnapshot.perfectIntact {
                        return "No verified breaks so far."
                    }

                    if !trackingManager.isGrayscaleEnabled {
                        return todayStatus.detail
                    }

                    if todaySnapshot.isQualifying {
                        return "Qualifies now."
                    }

                    return todayStatus.detail
                }()
                let ringProgress = goalSettings.qualifyingProgress(
                    totalVerifiedSeconds: todaySnapshot.totalVerifiedSeconds,
                    grayRate: todaySnapshot.grayRate
                )
                let heroOverlayDetail = HeroOverlayDetail(
                    title: trackingManager.isGrayscaleEnabled
                        ? (startedText.map { "Started \($0)" } ?? "Run active")
                        : quickReturnMethod.homePrompt,
                    subtitle: {
                        if trackingManager.isGrayscaleEnabled {
                            if todaySnapshot.perfectIntact {
                                return "Perfect still intact"
                            }

                            if todaySnapshot.isQualifying {
                                return "Still qualifies"
                            }

                            return "Below pace"
                        }

                        return todayStatus.detail
                    }(),
                    footnote: trackingManager.isGrayscaleEnabled
                        ? "Verified today \(DurationFormatter.statString(seconds: todaySnapshot.totalVerifiedSeconds))"
                        : startedText.map { "Out since \($0)" }
                )

                VStack(alignment: .leading, spacing: 20) {
                    RunTimerView(
                        activeRun: trackingManager.activeRun,
                        isGrayscaleActive: trackingManager.isGrayscaleEnabled,
                        currentOffStartTime: trackingManager.currentOffStartTime,
                        ringProgress: ringProgress,
                        isDamaged: dayIsDamaged,
                        isPristine: todaySnapshot.perfectIntact,
                        stateText: heroStateText,
                        supportingText: heroSupportingText,
                        isExpanded: isHeroExpanded,
                        expandedDetails: expandedDetails,
                        overlayDetail: heroOverlayDetail,
                        showsOverlayDetail: showHeroOverlay,
                        onTap: { isHeroExpanded.toggle() },
                        onLongPress: presentHeroOverlay,
                        referenceDate: now
                    )

                    SummaryCardsView(
                        todaySnapshot: todaySnapshot,
                        todayFooterText: todayFooterText,
                        currentQualifyingStreak: MetricsService.currentQualifyingStreak(from: mergedSnapshots, calendar: calendar, today: now),
                        bestQualifyingStreak: MetricsService.bestQualifyingStreak(from: mergedSnapshots, calendar: calendar),
                        bestDaySeconds: MetricsService.bestDay(from: mergedSnapshots),
                        sevenDayAverageRate: trendSummary.currentAverageRate,
                        onTodayTap: { showTodayDetailSheet = true }
                    )
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 30)
                .sheet(isPresented: $showTodayDetailSheet) {
                    DayDetailSheetView(snapshot: todaySnapshot, date: today, goalSettings: goalSettings)
                        .presentationDetents([.medium, .large])
                        .presentationDragIndicator(.visible)
                }
                .sensoryFeedback(.selection, trigger: isHeroExpanded)
                .sensoryFeedback(.impact(weight: .light, intensity: 0.7), trigger: showHeroOverlay)
            }
        }
        .scrollIndicators(.hidden)
        .background(MonochromeTheme.background.ignoresSafeArea())
        .navigationTitle("Grayscale Timer")
        .toolbarTitleDisplayMode(.inline)
        .onDisappear {
            heroOverlayDismissTask?.cancel()
            heroOverlayDismissTask = nil
        }
    }

    private func presentHeroOverlay() {
        heroOverlayDismissTask?.cancel()

        withAnimation(.spring(response: 0.24, dampingFraction: 0.84)) {
            showHeroOverlay = true
        }

        heroOverlayDismissTask = Task {
            try? await Task.sleep(for: .seconds(1.8))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.88)) {
                    showHeroOverlay = false
                }
            }
        }
    }
}
