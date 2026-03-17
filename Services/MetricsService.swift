import Foundation

struct DayMetricsSnapshot: Hashable, Identifiable {
    let date: Date
    let totalVerifiedSeconds: Double
    let breakCount: Int
    let longestRunSeconds: Double

    var id: Date { date }
    var qualified: Bool { totalVerifiedSeconds >= AppConfig.qualifyingThresholdSeconds }
    var perfect: Bool { qualified && breakCount == 0 }

    init(date: Date, totalVerifiedSeconds: Double, breakCount: Int, longestRunSeconds: Double) {
        self.date = date
        self.totalVerifiedSeconds = totalVerifiedSeconds
        self.breakCount = breakCount
        self.longestRunSeconds = longestRunSeconds
    }

    init(summary: DaySummary) {
        self.init(
            date: summary.date,
            totalVerifiedSeconds: summary.totalVerifiedSeconds,
            breakCount: summary.breakCount,
            longestRunSeconds: summary.longestRunSeconds
        )
    }

    static func empty(for date: Date) -> DayMetricsSnapshot {
        DayMetricsSnapshot(date: date, totalVerifiedSeconds: 0, breakCount: 0, longestRunSeconds: 0)
    }
}

struct HeatmapDay: Hashable, Identifiable {
    let date: Date
    let snapshot: DayMetricsSnapshot
    let intensity: Double

    var id: Date { date }
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

    static func daySnapshot(
        for dayStart: Date,
        runs: [RunRecord],
        calendar: Calendar,
        now: Date = .now,
        includeActive: Bool = true
    ) -> DayMetricsSnapshot {
        let normalizedDayStart = calendar.startOfDay(for: dayStart)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: normalizedDayStart) else {
            return .empty(for: normalizedDayStart)
        }

        var totalVerifiedSeconds: Double = 0
        var breakCount = 0
        var longestRunSeconds: Double = 0

        for run in runs {
            guard let effectiveEnd = effectiveEnd(for: run, now: now, includeActive: includeActive) else {
                continue
            }

            if run.startTime < dayEnd, effectiveEnd > normalizedDayStart {
                let overlapStart = max(run.startTime, normalizedDayStart)
                let overlapEnd = min(effectiveEnd, dayEnd)
                let overlap = overlapEnd.timeIntervalSince(overlapStart)

                if overlap > 0 {
                    totalVerifiedSeconds += overlap
                    longestRunSeconds = max(longestRunSeconds, overlap)
                }
            }

            if !run.isActive, let endTime = run.endTime, endTime >= normalizedDayStart, endTime < dayEnd {
                breakCount += 1
            }
        }

        return DayMetricsSnapshot(
            date: normalizedDayStart,
            totalVerifiedSeconds: totalVerifiedSeconds,
            breakCount: breakCount,
            longestRunSeconds: longestRunSeconds
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
        now: Date = .now
    ) -> [DayMetricsSnapshot] {
        var snapshotMap = Dictionary(uniqueKeysWithValues: summaries.map { ($0.date, DayMetricsSnapshot(summary: $0)) })

        for activeRun in runs where activeRun.isActive {
            for affectedDay in affectedDays(for: activeRun, calendar: calendar, now: now) {
                snapshotMap[affectedDay] = daySnapshot(
                    for: affectedDay,
                    runs: runs,
                    calendar: calendar,
                    now: now,
                    includeActive: true
                )
            }
        }

        return snapshotMap.values.sorted { $0.date < $1.date }
    }

    static func currentStreak(
        from snapshots: [DayMetricsSnapshot],
        calendar: Calendar,
        today: Date = .now
    ) -> Int {
        let qualifiedDays = Set(snapshots.filter(\.qualified).map(\.date))
        let todayStart = calendar.startOfDay(for: today)
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: todayStart) else {
            return 0
        }

        let anchor: Date
        if qualifiedDays.contains(todayStart) {
            anchor = todayStart
        } else if qualifiedDays.contains(yesterday) {
            anchor = yesterday
        } else {
            return 0
        }

        var streak = 0
        var currentDay = anchor

        while qualifiedDays.contains(currentDay) {
            streak += 1

            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: currentDay) else {
                break
            }

            currentDay = previousDay
        }

        return streak
    }

    static func bestStreak(from snapshots: [DayMetricsSnapshot], calendar: Calendar) -> Int {
        let qualifiedDays = snapshots
            .filter(\.qualified)
            .map(\.date)
            .sorted()

        guard var previous = qualifiedDays.first else { return 0 }

        var best = 1
        var current = 1

        for day in qualifiedDays.dropFirst() {
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

    static func qualifyingDayCount(from snapshots: [DayMetricsSnapshot]) -> Int {
        snapshots.filter(\.qualified).count
    }

    static func perfectDayCount(from snapshots: [DayMetricsSnapshot]) -> Int {
        snapshots.filter(\.perfect).count
    }

    static func heatmapData(
        summaries: [DaySummary],
        runs: [RunRecord],
        calendar: Calendar,
        now: Date = .now,
        dayCount: Int = AppConfig.heatmapDayCount
    ) -> [HeatmapDay] {
        let snapshotMap = Dictionary(
            uniqueKeysWithValues: mergedDaySnapshots(summaries: summaries, runs: runs, calendar: calendar, now: now)
                .map { ($0.date, $0) }
        )

        let today = calendar.startOfDay(for: now)

        return (0..<dayCount).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -(dayCount - offset - 1), to: today) else {
                return nil
            }

            let snapshot = snapshotMap[day] ?? .empty(for: day)
            return HeatmapDay(date: day, snapshot: snapshot, intensity: intensity(for: snapshot))
        }
    }

    static func intensity(for snapshot: DayMetricsSnapshot) -> Double {
        if snapshot.perfect {
            return 1.0
        }

        if snapshot.qualified {
            return 0.86
        }

        if snapshot.totalVerifiedSeconds <= 0 {
            return 0.08
        }

        let ratio = min(snapshot.totalVerifiedSeconds / AppConfig.qualifyingThresholdSeconds, 1)
        return 0.14 + (ratio * 0.54)
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
