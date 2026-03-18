import Foundation

enum DayStatus: String, Hashable {
    case perfect
    case strong
    case qualifying
    case missed

    var title: String {
        switch self {
        case .perfect:
            return "Perfect"
        case .strong:
            return "Strong"
        case .qualifying:
            return "Qualifying"
        case .missed:
            return "Missed"
        }
    }
}

struct DayMetricsSnapshot: Hashable, Identifiable {
    let date: Date
    let totalVerifiedSeconds: Double
    let breakCount: Int
    let longestRunSeconds: Double
    let relapseSeconds: Double
    let eligibleSeconds: Double
    let grayRate: Double
    let isQualifying: Bool
    let isStrong: Bool
    let isPerfect: Bool
    let perfectIntact: Bool
    let status: DayStatus

    var id: Date { date }

    static func empty(for date: Date) -> DayMetricsSnapshot {
        DayMetricsSnapshot(
            date: date,
            totalVerifiedSeconds: 0,
            breakCount: 0,
            longestRunSeconds: 0,
            relapseSeconds: 0,
            eligibleSeconds: 0,
            grayRate: 0,
            isQualifying: false,
            isStrong: false,
            isPerfect: false,
            perfectIntact: false,
            status: .missed
        )
    }
}

struct DayTimelineSegment: Hashable, Identifiable {
    let startFraction: Double
    let endFraction: Double

    var id: String {
        "\(startFraction)-\(endFraction)"
    }
}

struct DayTimelineSnapshot: Hashable {
    let segments: [DayTimelineSegment]
    let breakFractions: [Double]
    let currentFraction: Double

    static let empty = DayTimelineSnapshot(segments: [], breakFractions: [], currentFraction: 0)
}

struct HeatmapDay: Hashable, Identifiable {
    let date: Date
    let snapshot: DayMetricsSnapshot
    let intensity: Double

    var id: Date { date }
}

struct TrendSummary: Hashable {
    let currentAverageRate: Double
    let previousAverageRate: Double
    let recentAverageRecoverySeconds: Double?

    var delta: Double { currentAverageRate - previousAverageRate }
}

struct RecoverySummary: Hashable {
    let latestRecoverySeconds: Double?
    let recentAverageRecoverySeconds: Double?
}

struct WeeklyAggregate: Hashable, Identifiable {
    let startDate: Date
    let averageGrayRate: Double
    let perfectDayCount: Int

    var id: Date { startDate }
}

struct TodayStatusSummary: Hashable {
    let title: String
    let detail: String
}

enum MetricsService {
    static func runDuration(for run: RunRecord, now: Date = .now) -> Double {
        if run.isActive {
            return max(0, now.timeIntervalSince(run.startTime))
        }

        if let endTime = run.endTime {
            return max(0, endTime.timeIntervalSince(run.startTime))
        }

        return max(0, run.durationSecondsCached)
    }

    static func bestRun(from runs: [RunRecord], now: Date = .now) -> Double {
        runs.map { runDuration(for: $0, now: now) }.max() ?? 0
    }

    static func bestDay(from snapshots: [DayMetricsSnapshot]) -> Double {
        snapshots.map(\.totalVerifiedSeconds).max() ?? 0
    }

    static func lifetimeVerifiedSeconds(from snapshots: [DayMetricsSnapshot]) -> Double {
        snapshots.reduce(0) { $0 + $1.totalVerifiedSeconds }
    }

    static func daySnapshot(
        for dayStart: Date,
        runs: [RunRecord],
        calendar: Calendar,
        now: Date = .now,
        includeActive: Bool = true,
        goalSettings: GoalSettings = GoalSettingsStore.load()
    ) -> DayMetricsSnapshot {
        let normalizedDayStart = calendar.startOfDay(for: dayStart)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: normalizedDayStart) else {
            return .empty(for: normalizedDayStart)
        }

        let measurementEnd = boundedMeasurementEnd(
            dayStart: normalizedDayStart,
            dayEnd: dayEnd,
            now: now
        )

        var totalVerifiedSeconds: Double = 0
        var breakCount = 0
        var longestRunSeconds: Double = 0
        var firstVerifiedStart: Date?

        for run in runs {
            guard let effectiveEnd = effectiveEnd(for: run, now: now, includeActive: includeActive) else {
                continue
            }

            if run.startTime < measurementEnd, effectiveEnd > normalizedDayStart {
                let overlapStart = max(run.startTime, normalizedDayStart)
                let overlapEnd = min(effectiveEnd, measurementEnd)
                let overlap = overlapEnd.timeIntervalSince(overlapStart)

                if overlap > 0 {
                    totalVerifiedSeconds += overlap
                    longestRunSeconds = max(longestRunSeconds, overlap)
                    firstVerifiedStart = min(firstVerifiedStart ?? overlapStart, overlapStart)
                }
            }

            if !run.isActive, let endTime = run.endTime, endTime >= normalizedDayStart, endTime < dayEnd {
                breakCount += 1
            }
        }

        let eligibleSeconds = max(0, measurementEnd.timeIntervalSince(normalizedDayStart))
        let grayRate = eligibleSeconds > 0 ? min(totalVerifiedSeconds / eligibleSeconds, 1) : 0
        let relapseSeconds: Double

        if let firstVerifiedStart {
            relapseSeconds = max(0, measurementEnd.timeIntervalSince(firstVerifiedStart) - totalVerifiedSeconds)
        } else {
            relapseSeconds = 0
        }

        let isQualifying = goalSettings.isQualifying(
            totalVerifiedSeconds: totalVerifiedSeconds,
            grayRate: grayRate
        )
        let isStrong = goalSettings.isStrong(
            totalVerifiedSeconds: totalVerifiedSeconds,
            grayRate: grayRate
        )
        let perfectIntact = breakCount == 0 && totalVerifiedSeconds > 0
        let isPerfect = perfectIntact && (!goalSettings.perfectRequiresQualification || isQualifying)

        let status: DayStatus
        if isPerfect {
            status = .perfect
        } else if isStrong {
            status = .strong
        } else if isQualifying {
            status = .qualifying
        } else {
            status = .missed
        }

        return DayMetricsSnapshot(
            date: normalizedDayStart,
            totalVerifiedSeconds: totalVerifiedSeconds,
            breakCount: breakCount,
            longestRunSeconds: longestRunSeconds,
            relapseSeconds: relapseSeconds,
            eligibleSeconds: eligibleSeconds,
            grayRate: grayRate,
            isQualifying: isQualifying,
            isStrong: isStrong,
            isPerfect: isPerfect,
            perfectIntact: perfectIntact,
            status: status
        )
    }

    static func dayTimeline(
        for dayStart: Date,
        runs: [RunRecord],
        calendar: Calendar,
        now: Date = .now,
        includeActive: Bool = true
    ) -> DayTimelineSnapshot {
        let normalizedDayStart = calendar.startOfDay(for: dayStart)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: normalizedDayStart) else {
            return .empty
        }

        let measurementEnd = boundedMeasurementEnd(
            dayStart: normalizedDayStart,
            dayEnd: dayEnd,
            now: now
        )
        let fullDaySeconds = max(dayEnd.timeIntervalSince(normalizedDayStart), 1)

        let segments = runs.compactMap { run -> DayTimelineSegment? in
            guard let effectiveEnd = effectiveEnd(for: run, now: now, includeActive: includeActive) else {
                return nil
            }
            guard run.startTime < measurementEnd, effectiveEnd > normalizedDayStart else {
                return nil
            }

            let overlapStart = max(run.startTime, normalizedDayStart)
            let overlapEnd = min(effectiveEnd, measurementEnd)
            guard overlapEnd > overlapStart else { return nil }

            return DayTimelineSegment(
                startFraction: max(0, min(overlapStart.timeIntervalSince(normalizedDayStart) / fullDaySeconds, 1)),
                endFraction: max(0, min(overlapEnd.timeIntervalSince(normalizedDayStart) / fullDaySeconds, 1))
            )
        }

        let breakFractions = runs.compactMap { run -> Double? in
            guard !run.isActive, let endTime = run.endTime else { return nil }
            guard endTime >= normalizedDayStart, endTime <= measurementEnd else { return nil }

            return max(0, min(endTime.timeIntervalSince(normalizedDayStart) / fullDaySeconds, 1))
        }

        return DayTimelineSnapshot(
            segments: segments.sorted { $0.startFraction < $1.startFraction },
            breakFractions: breakFractions.sorted(),
            currentFraction: max(0, min(measurementEnd.timeIntervalSince(normalizedDayStart) / fullDaySeconds, 1))
        )
    }

    static func affectedDays(for run: RunRecord, calendar: Calendar, now: Date = .now) -> [Date] {
        guard let effectiveEnd = effectiveEnd(for: run, now: now, includeActive: true) else {
            return [calendar.startOfDay(for: run.startTime)]
        }

        var days: [Date] = []
        var currentDay = calendar.startOfDay(for: run.startTime)
        let lastDay = calendar.startOfDay(for: effectiveEnd)

        while currentDay <= lastDay {
            days.append(currentDay)

            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: currentDay) else {
                break
            }

            currentDay = nextDay
        }

        return days
    }

    static func mergedDaySnapshots(
        summaries: [DaySummary],
        runs: [RunRecord],
        calendar: Calendar,
        now: Date = .now,
        goalSettings: GoalSettings = GoalSettingsStore.load()
    ) -> [DayMetricsSnapshot] {
        var days = Set(summaries.map(\.date))

        for run in runs where run.isActive {
            days.formUnion(affectedDays(for: run, calendar: calendar, now: now))
        }

        return days
            .sorted()
            .map {
                daySnapshot(
                    for: $0,
                    runs: runs,
                    calendar: calendar,
                    now: now,
                    includeActive: true,
                    goalSettings: goalSettings
                )
            }
    }

    static func currentStreak(
        from snapshots: [DayMetricsSnapshot],
        calendar: Calendar,
        today: Date = .now
    ) -> Int {
        currentQualifyingStreak(from: snapshots, calendar: calendar, today: today)
    }

    static func currentQualifyingStreak(
        from snapshots: [DayMetricsSnapshot],
        calendar: Calendar,
        today: Date = .now
    ) -> Int {
        currentStreak(
            matching: Set(snapshots.filter(\.isQualifying).map(\.date)),
            calendar: calendar,
            today: today
        )
    }

    static func currentPerfectStreak(
        from snapshots: [DayMetricsSnapshot],
        calendar: Calendar,
        today: Date = .now
    ) -> Int {
        currentStreak(
            matching: Set(snapshots.filter(\.isPerfect).map(\.date)),
            calendar: calendar,
            today: today
        )
    }

    static func bestStreak(from snapshots: [DayMetricsSnapshot], calendar: Calendar) -> Int {
        bestQualifyingStreak(from: snapshots, calendar: calendar)
    }

    static func bestQualifyingStreak(from snapshots: [DayMetricsSnapshot], calendar: Calendar) -> Int {
        bestStreak(
            matching: snapshots.filter(\.isQualifying).map(\.date).sorted(),
            calendar: calendar
        )
    }

    static func bestPerfectStreak(from snapshots: [DayMetricsSnapshot], calendar: Calendar) -> Int {
        bestStreak(
            matching: snapshots.filter(\.isPerfect).map(\.date).sorted(),
            calendar: calendar
        )
    }

    static func qualifyingDayCount(from snapshots: [DayMetricsSnapshot]) -> Int {
        snapshots.filter(\.isQualifying).count
    }

    static func perfectDayCount(from snapshots: [DayMetricsSnapshot]) -> Int {
        snapshots.filter(\.isPerfect).count
    }

    static func heatmapData(
        summaries: [DaySummary],
        runs: [RunRecord],
        calendar: Calendar,
        now: Date = .now,
        dayCount: Int = AppConfig.heatmapDayCount,
        goalSettings: GoalSettings = GoalSettingsStore.load()
    ) -> [HeatmapDay] {
        let today = calendar.startOfDay(for: now)

        return (0..<dayCount).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -(dayCount - offset - 1), to: today) else {
                return nil
            }

            let snapshot = daySnapshot(
                for: day,
                runs: runs,
                calendar: calendar,
                now: now,
                includeActive: true,
                goalSettings: goalSettings
            )

            return HeatmapDay(date: day, snapshot: snapshot, intensity: intensity(for: snapshot))
        }
    }

    static func intensity(for snapshot: DayMetricsSnapshot) -> Double {
        if snapshot.grayRate <= 0 {
            return 0.08
        }

        return 0.12 + (snapshot.grayRate * 0.82)
    }

    static func todayStatusSummary(
        for snapshot: DayMetricsSnapshot,
        calendar: Calendar,
        now: Date = .now,
        isGrayscaleActive: Bool,
        goalSettings: GoalSettings
    ) -> TodayStatusSummary {
        let dayStart = calendar.startOfDay(for: snapshot.date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? now
        let fullDaySeconds = max(dayEnd.timeIntervalSince(dayStart), 1)
        let remainingSeconds = max(0, dayEnd.timeIntervalSince(now))
        let projectedVerifiedSeconds = min(fullDaySeconds, snapshot.grayRate * fullDaySeconds)
        let maxPossibleVerifiedSeconds = min(fullDaySeconds, snapshot.totalVerifiedSeconds + remainingSeconds)
        let maxPossibleGrayRate = min(maxPossibleVerifiedSeconds / fullDaySeconds, 1)

        if snapshot.perfectIntact {
            return TodayStatusSummary(
                title: "Perfect day intact",
                detail: isGrayscaleActive ? "No verified breaks so far." : "Return now to keep the day clean."
            )
        }

        if goalSettings.isStrong(
            totalVerifiedSeconds: projectedVerifiedSeconds,
            grayRate: snapshot.grayRate
        ) {
            return TodayStatusSummary(
                title: "On track for a strong day",
                detail: "Current gray rate is \(percentString(snapshot.grayRate))."
            )
        }

        if goalSettings.isQualifying(
            totalVerifiedSeconds: maxPossibleVerifiedSeconds,
            grayRate: maxPossibleGrayRate
        ) {
            return TodayStatusSummary(
                title: "Still possible to qualify today",
                detail: isGrayscaleActive ? "Stay in grayscale to secure the day." : "Return now to recover pace."
            )
        }

        return TodayStatusSummary(
            title: "Below pace",
            detail: "Even a full return would miss today’s goal."
        )
    }

    static func trendSummary(
        summaries: [DaySummary],
        runs: [RunRecord],
        calendar: Calendar,
        now: Date = .now,
        goalSettings: GoalSettings,
        windowSize: Int = 7
    ) -> TrendSummary {
        let currentSnapshots = snapshots(
            endingOn: now,
            dayCount: windowSize,
            runs: runs,
            calendar: calendar,
            now: now,
            goalSettings: goalSettings
        )
        let previousAnchor = calendar.date(byAdding: .day, value: -windowSize, to: now) ?? now
        let previousSnapshots = snapshots(
            endingOn: previousAnchor,
            dayCount: windowSize,
            runs: runs,
            calendar: calendar,
            now: now,
            goalSettings: goalSettings
        )

        let recovery = recoverySummary(from: runs, now: now)

        return TrendSummary(
            currentAverageRate: averageGrayRate(from: currentSnapshots),
            previousAverageRate: averageGrayRate(from: previousSnapshots),
            recentAverageRecoverySeconds: recovery.recentAverageRecoverySeconds
        )
    }

    static func recoverySummary(from runs: [RunRecord], now: Date = .now, recentWindowDays: Int = 14) -> RecoverySummary {
        let completedRecoveries = recoveryEvents(from: runs, now: now)
        let recentCutoff = now.addingTimeInterval(-Double(recentWindowDays) * 86_400)
        let recentRecoveries = completedRecoveries
            .filter { $0.recoveredAt >= recentCutoff }
            .map(\.duration)

        return RecoverySummary(
            latestRecoverySeconds: completedRecoveries.last?.duration,
            recentAverageRecoverySeconds: recentRecoveries.isEmpty ? nil : recentRecoveries.reduce(0, +) / Double(recentRecoveries.count)
        )
    }

    static func latestBreakDate(from runs: [RunRecord]) -> Date? {
        runs
            .compactMap(\.endTime)
            .max()
    }

    static func weeklyAggregates(
        summaries: [DaySummary],
        runs: [RunRecord],
        calendar: Calendar,
        now: Date = .now,
        goalSettings: GoalSettings
    ) -> [WeeklyAggregate] {
        let merged = mergedDaySnapshots(
            summaries: summaries,
            runs: runs,
            calendar: calendar,
            now: now,
            goalSettings: goalSettings
        )
        let startDate = earliestRelevantDate(from: summaries, runs: runs, calendar: calendar, now: now)
        let endDate = calendar.startOfDay(for: now)
        let dayRange = dayRange(from: startDate, through: endDate, calendar: calendar)
        let snapshotMap = Dictionary(uniqueKeysWithValues: merged.map { ($0.date, $0) })

        var grouped: [Date: [DayMetricsSnapshot]] = [:]

        for day in dayRange {
            let weekStart = calendar.dateInterval(of: .weekOfYear, for: day)?.start ?? day
            let snapshot = snapshotMap[day] ?? daySnapshot(
                for: day,
                runs: runs,
                calendar: calendar,
                now: now,
                includeActive: true,
                goalSettings: goalSettings
            )
            grouped[weekStart, default: []].append(snapshot)
        }

        return grouped
            .map { weekStart, snapshots in
                WeeklyAggregate(
                    startDate: weekStart,
                    averageGrayRate: averageGrayRate(from: snapshots),
                    perfectDayCount: snapshots.filter(\.isPerfect).count
                )
            }
            .sorted { $0.startDate < $1.startDate }
    }

    static func summaryText(for snapshot: DayMetricsSnapshot, goalSettings: GoalSettings) -> String? {
        switch snapshot.status {
        case .perfect:
            if snapshot.isStrong {
                return marginText(
                    achievedValue: metricValue(for: snapshot, goalSettings: goalSettings, useStrongThreshold: true),
                    thresholdValue: strongThresholdValue(goalSettings: goalSettings),
                    goalSettings: goalSettings,
                    prefix: "Strong by"
                )
            }

            if snapshot.isQualifying {
                return marginText(
                    achievedValue: metricValue(for: snapshot, goalSettings: goalSettings, useStrongThreshold: false),
                    thresholdValue: qualifyingThresholdValue(goalSettings: goalSettings),
                    goalSettings: goalSettings,
                    prefix: "Qualified by"
                )
            }

            return "No breaks recorded."
        case .strong:
            return marginText(
                achievedValue: metricValue(for: snapshot, goalSettings: goalSettings, useStrongThreshold: true),
                thresholdValue: strongThresholdValue(goalSettings: goalSettings),
                goalSettings: goalSettings,
                prefix: "Strong by"
            )
        case .qualifying:
            return marginText(
                achievedValue: metricValue(for: snapshot, goalSettings: goalSettings, useStrongThreshold: false),
                thresholdValue: qualifyingThresholdValue(goalSettings: goalSettings),
                goalSettings: goalSettings,
                prefix: "Qualified by"
            )
        case .missed:
            return marginText(
                achievedValue: metricValue(for: snapshot, goalSettings: goalSettings, useStrongThreshold: false),
                thresholdValue: qualifyingThresholdValue(goalSettings: goalSettings),
                goalSettings: goalSettings,
                prefix: "Missed by",
                invert: true
            )
        }
    }

    private static func boundedMeasurementEnd(dayStart: Date, dayEnd: Date, now: Date) -> Date {
        min(max(now, dayStart), dayEnd)
    }

    private static func currentStreak(
        matching dates: Set<Date>,
        calendar: Calendar,
        today: Date
    ) -> Int {
        let todayStart = calendar.startOfDay(for: today)
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: todayStart) else {
            return 0
        }

        let anchor: Date
        if dates.contains(todayStart) {
            anchor = todayStart
        } else if dates.contains(yesterday) {
            anchor = yesterday
        } else {
            return 0
        }

        var streak = 0
        var currentDay = anchor

        while dates.contains(currentDay) {
            streak += 1

            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: currentDay) else {
                break
            }

            currentDay = previousDay
        }

        return streak
    }

    private static func bestStreak(matching dates: [Date], calendar: Calendar) -> Int {
        guard var previous = dates.first else { return 0 }

        var best = 1
        var current = 1

        for day in dates.dropFirst() {
            if let expectedNext = calendar.date(byAdding: .day, value: 1, to: previous), calendar.isDate(day, inSameDayAs: expectedNext) {
                current += 1
            } else {
                current = 1
            }

            best = max(best, current)
            previous = day
        }

        return best
    }

    private static func recoveryEvents(from runs: [RunRecord], now: Date) -> [(duration: Double, recoveredAt: Date)] {
        let sortedRuns = runs.sorted { $0.startTime < $1.startTime }
        var events: [(duration: Double, recoveredAt: Date)] = []

        for pair in zip(sortedRuns, sortedRuns.dropFirst()) {
            let first = pair.0
            let second = pair.1

            guard let firstEnd = effectiveEnd(for: first, now: now, includeActive: true) else {
                continue
            }

            let gap = second.startTime.timeIntervalSince(firstEnd)
            if gap > 0 {
                events.append((duration: gap, recoveredAt: second.startTime))
            }
        }

        return events
    }

    private static func snapshots(
        endingOn anchorDate: Date,
        dayCount: Int,
        runs: [RunRecord],
        calendar: Calendar,
        now: Date,
        goalSettings: GoalSettings
    ) -> [DayMetricsSnapshot] {
        let anchor = calendar.startOfDay(for: anchorDate)

        return (0..<dayCount).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -(dayCount - offset - 1), to: anchor) else {
                return nil
            }

            return daySnapshot(
                for: day,
                runs: runs,
                calendar: calendar,
                now: now,
                includeActive: true,
                goalSettings: goalSettings
            )
        }
    }

    private static func averageGrayRate(from snapshots: [DayMetricsSnapshot]) -> Double {
        guard !snapshots.isEmpty else { return 0 }
        return snapshots.reduce(0) { $0 + $1.grayRate } / Double(snapshots.count)
    }

    private static func earliestRelevantDate(
        from summaries: [DaySummary],
        runs: [RunRecord],
        calendar: Calendar,
        now: Date
    ) -> Date {
        let earliestSummaryDate = summaries.map(\.date).min()
        let earliestRunDate = runs.map { calendar.startOfDay(for: $0.startTime) }.min()
        return [earliestSummaryDate, earliestRunDate, calendar.startOfDay(for: now)]
            .compactMap { $0 }
            .min() ?? calendar.startOfDay(for: now)
    }

    private static func dayRange(from startDate: Date, through endDate: Date, calendar: Calendar) -> [Date] {
        var dates: [Date] = []
        var cursor = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)

        while cursor <= end {
            dates.append(cursor)

            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else {
                break
            }

            cursor = next
        }

        return dates
    }

    private static func metricValue(for snapshot: DayMetricsSnapshot, goalSettings: GoalSettings, useStrongThreshold: Bool) -> Double {
        switch goalSettings.mode {
        case .percentage:
            return snapshot.grayRate
        case .fixedHours:
            return snapshot.totalVerifiedSeconds
        }
    }

    private static func qualifyingThresholdValue(goalSettings: GoalSettings) -> Double {
        switch goalSettings.mode {
        case .percentage:
            return goalSettings.qualifyingRate
        case .fixedHours:
            return goalSettings.fixedQualifyingSeconds
        }
    }

    private static func strongThresholdValue(goalSettings: GoalSettings) -> Double {
        switch goalSettings.mode {
        case .percentage:
            return goalSettings.strongRate
        case .fixedHours:
            return goalSettings.fixedStrongSeconds
        }
    }

    private static func marginText(
        achievedValue: Double,
        thresholdValue: Double,
        goalSettings: GoalSettings,
        prefix: String,
        invert: Bool = false
    ) -> String {
        let delta = invert ? max(0, thresholdValue - achievedValue) : max(0, achievedValue - thresholdValue)

        switch goalSettings.mode {
        case .percentage:
            return "\(prefix) \(percentString(delta))"
        case .fixedHours:
            return "\(prefix) \(DurationFormatter.statString(seconds: delta))"
        }
    }

    private static func percentString(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    private static func effectiveEnd(
        for run: RunRecord,
        now: Date,
        includeActive: Bool
    ) -> Date? {
        if run.isActive {
            return includeActive ? now : nil
        }

        return run.endTime
    }
}
