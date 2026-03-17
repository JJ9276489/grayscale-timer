import Foundation
import SwiftData
import SwiftUI
import UIKit
import WidgetKit

@MainActor
final class GrayscaleTrackingManager: ObservableObject {
    @Published private(set) var isGrayscaleEnabled = false
    @Published private(set) var activeRun: RunRecord?
    @Published private(set) var currentOffStartTime: Date?

    let calendar: Calendar

    private let modelContext: ModelContext
    private let userDefaults: UserDefaults
    private var grayscaleObserver: NSObjectProtocol?
    private var checkpointTimer: Timer?
    private var pendingBreakTimer: Timer?

    private enum DefaultsKey {
        static let lastVerifiedOnTimestamp = "grayscale_last_verified_on_timestamp"
        static let currentOffTimestamp = "grayscale_current_off_timestamp"
    }

    init(modelContext: ModelContext, calendar: Calendar = .autoupdatingCurrent) {
        self.modelContext = modelContext
        self.calendar = calendar
        self.userDefaults = .standard

        installNotificationObserver()
        recoverStateOnLaunch()
    }

    func handleScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .active:
            refreshFromSystem()
        case .inactive, .background:
            if isGrayscaleEnabled, activeRun != nil {
                persistVerificationCheckpoint(at: .now)
            }

            saveContextIfNeeded()
            publishWidgetSnapshot(referenceDate: .now)
        @unknown default:
            break
        }
    }

    private func installNotificationObserver() {
        grayscaleObserver = NotificationCenter.default.addObserver(
            forName: UIAccessibility.grayscaleStatusDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refreshFromSystem()
            }
        }
    }

    private func recoverStateOnLaunch() {
        activeRun = try? fetchActiveRun()
        currentOffStartTime = restoredOffStartTime()
        refreshFromSystem()
    }

    private func refreshFromSystem() {
        let currentState = UIAccessibility.isGrayscaleEnabled
        let now = Date()

        isGrayscaleEnabled = currentState

        if currentState {
            clearOffState()
            if activeRun == nil {
                beginVerifiedRun(at: now)
            } else {
                persistVerificationCheckpoint(at: now)
            }
        } else if let activeRun {
            handlePendingBreak(for: activeRun, fallback: now)
        } else if currentOffStartTime == nil {
            currentOffStartTime = (try? fetchLatestBreakDate()) ?? currentOffStartTime
            persistOffStartTimeIfNeeded()
        }

        updateCheckpointTimer()
        publishWidgetSnapshot(referenceDate: now)
    }

    private func beginVerifiedRun(at startTime: Date) {
        let run = RunRecord(startTime: startTime, isActive: true)
        modelContext.insert(run)
        activeRun = run
        persistVerificationCheckpoint(at: startTime)
        saveContextIfNeeded()
    }

    private func endVerifiedRun(at endTime: Date) {
        guard let activeRun else { return }

        let normalizedEnd = max(activeRun.startTime, endTime)
        activeRun.endTime = normalizedEnd
        activeRun.isActive = false
        activeRun.durationSecondsCached = normalizedEnd.timeIntervalSince(activeRun.startTime)

        let affectedDays = Set(MetricsService.affectedDays(for: activeRun, calendar: calendar, now: normalizedEnd))

        self.activeRun = nil
        userDefaults.removeObject(forKey: DefaultsKey.lastVerifiedOnTimestamp)
        rebuildSummaries(for: affectedDays)
        saveContextIfNeeded()
    }

    private func handlePendingBreak(for activeRun: RunRecord, fallback: Date) {
        let offStart = currentOffStartTime ?? recoveredEndDate(for: activeRun, fallback: fallback)
        currentOffStartTime = offStart
        persistOffStartTimeIfNeeded()

        let debounceSeconds = GoalSettingsStore.load(userDefaults: userDefaults).breakDebounceSeconds

        if debounceSeconds <= 0 {
            finalizeBreak(at: offStart)
            return
        }

        schedulePendingBreak(at: offStart, debounceSeconds: debounceSeconds)
    }

    private func schedulePendingBreak(at offStart: Date, debounceSeconds: TimeInterval) {
        pendingBreakTimer?.invalidate()

        let remainingInterval = max(0, offStart.addingTimeInterval(debounceSeconds).timeIntervalSinceNow)

        pendingBreakTimer = Timer.scheduledTimer(withTimeInterval: remainingInterval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                guard !UIAccessibility.isGrayscaleEnabled else { return }
                self.finalizeBreak(at: offStart)
                self.publishWidgetSnapshot(referenceDate: .now)
            }
        }

        pendingBreakTimer?.tolerance = min(5, debounceSeconds / 3)
    }

    private func finalizeBreak(at offStart: Date) {
        pendingBreakTimer?.invalidate()
        pendingBreakTimer = nil
        endVerifiedRun(at: offStart)
    }

    private func rebuildSummaries(for days: Set<Date>) {
        guard !days.isEmpty else { return }

        let allRuns = (try? fetchAllRuns()) ?? []
        let completedRuns = allRuns.filter { !$0.isActive && $0.endTime != nil }
        let existingSummaries = (try? fetchAllSummaries()) ?? []
        var existingByDate = Dictionary(uniqueKeysWithValues: existingSummaries.map { ($0.date, $0) })
        let goalSettings = GoalSettingsStore.load(userDefaults: userDefaults)

        for day in days {
            let snapshot = MetricsService.daySnapshot(
                for: day,
                runs: completedRuns,
                calendar: calendar,
                now: .now,
                includeActive: false,
                goalSettings: goalSettings
            )

            if snapshot.totalVerifiedSeconds <= 0, snapshot.breakCount == 0, snapshot.longestRunSeconds <= 0 {
                if let existing = existingByDate.removeValue(forKey: day) {
                    modelContext.delete(existing)
                }
                continue
            }

            let summary = existingByDate[day] ?? DaySummary(date: day, calendar: calendar)
            summary.date = calendar.startOfDay(for: day)
            summary.totalVerifiedSeconds = snapshot.totalVerifiedSeconds
            summary.breakCount = snapshot.breakCount
            summary.longestRunSeconds = snapshot.longestRunSeconds
            summary.qualified = snapshot.isQualifying
            summary.perfect = snapshot.isPerfect

            if existingByDate[day] == nil {
                modelContext.insert(summary)
            }
        }
    }

    private func publishWidgetSnapshot(referenceDate: Date) {
        let runs = (try? fetchAllRuns()) ?? []
        let summaries = (try? fetchAllSummaries()) ?? []
        let goalSettings = GoalSettingsStore.load(userDefaults: userDefaults)
        let mergedSnapshots = MetricsService.mergedDaySnapshots(
            summaries: summaries,
            runs: runs,
            calendar: calendar,
            now: referenceDate,
            goalSettings: goalSettings
        )

        let snapshot = WidgetSnapshot(
            isActive: isGrayscaleEnabled && activeRun != nil,
            activeRunStartTime: activeRun?.startTime,
            currentStreak: MetricsService.currentQualifyingStreak(from: mergedSnapshots, calendar: calendar, today: referenceDate),
            lastUpdated: referenceDate
        )

        WidgetSnapshotStore.save(snapshot)
        WidgetCenter.shared.reloadTimelines(ofKind: AppConfig.widgetKind)
    }

    private func updateCheckpointTimer() {
        checkpointTimer?.invalidate()

        guard isGrayscaleEnabled, activeRun != nil else {
            checkpointTimer = nil
            return
        }

        checkpointTimer = Timer.scheduledTimer(withTimeInterval: AppConfig.verificationCheckpointInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                let now = Date()
                self.persistVerificationCheckpoint(at: now)
                self.publishWidgetSnapshot(referenceDate: now)
            }
        }

        checkpointTimer?.tolerance = 10
    }

    private func persistVerificationCheckpoint(at date: Date) {
        userDefaults.set(date.timeIntervalSinceReferenceDate, forKey: DefaultsKey.lastVerifiedOnTimestamp)
    }

    private func persistOffStartTimeIfNeeded() {
        if let currentOffStartTime {
            userDefaults.set(currentOffStartTime.timeIntervalSinceReferenceDate, forKey: DefaultsKey.currentOffTimestamp)
        } else {
            userDefaults.removeObject(forKey: DefaultsKey.currentOffTimestamp)
        }
    }

    private func restoredOffStartTime() -> Date? {
        guard let interval = userDefaults.object(forKey: DefaultsKey.currentOffTimestamp) as? Double else {
            return nil
        }

        return Date(timeIntervalSinceReferenceDate: interval)
    }

    private func clearOffState() {
        pendingBreakTimer?.invalidate()
        pendingBreakTimer = nil
        currentOffStartTime = nil
        userDefaults.removeObject(forKey: DefaultsKey.currentOffTimestamp)
    }

    private func recoveredEndDate(for run: RunRecord, fallback: Date) -> Date {
        guard let interval = userDefaults.object(forKey: DefaultsKey.lastVerifiedOnTimestamp) as? Double else {
            return fallback
        }

        let recoveredDate = Date(timeIntervalSinceReferenceDate: interval)
        return max(run.startTime, min(fallback, recoveredDate))
    }

    private func fetchActiveRun() throws -> RunRecord? {
        var descriptor = FetchDescriptor<RunRecord>(
            predicate: #Predicate { $0.isActive == true },
            sortBy: [SortDescriptor(\RunRecord.startTime, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    private func fetchAllRuns() throws -> [RunRecord] {
        let descriptor = FetchDescriptor<RunRecord>(
            sortBy: [SortDescriptor(\RunRecord.startTime, order: .forward)]
        )
        return try modelContext.fetch(descriptor)
    }

    private func fetchLatestBreakDate() throws -> Date? {
        try fetchAllRuns()
            .compactMap(\.endTime)
            .max()
    }

    private func fetchAllSummaries() throws -> [DaySummary] {
        let descriptor = FetchDescriptor<DaySummary>(
            sortBy: [SortDescriptor(\DaySummary.date, order: .forward)]
        )
        return try modelContext.fetch(descriptor)
    }

    private func saveContextIfNeeded() {
        guard modelContext.hasChanges else { return }
        try? modelContext.save()
    }
}

#if DEBUG
extension GrayscaleTrackingManager {
    static func preview(
        modelContext: ModelContext,
        isGrayscaleEnabled: Bool,
        activeRun: RunRecord?,
        currentOffStartTime: Date? = nil
    ) -> GrayscaleTrackingManager {
        let manager = GrayscaleTrackingManager(modelContext: modelContext)
        manager.isGrayscaleEnabled = isGrayscaleEnabled
        manager.activeRun = activeRun
        manager.currentOffStartTime = currentOffStartTime
        return manager
    }
}
#endif
