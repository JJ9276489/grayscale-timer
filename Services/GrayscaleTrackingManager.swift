import Foundation
import SwiftData
import SwiftUI
import UIKit
import WidgetKit

@MainActor
final class GrayscaleTrackingManager: ObservableObject {
    @Published private(set) var isGrayscaleEnabled = false
    @Published private(set) var activeRun: RunRecord?

    let calendar: Calendar

    private let modelContext: ModelContext
    private let userDefaults: UserDefaults
    private var grayscaleObserver: NSObjectProtocol?
    private var checkpointTimer: Timer?

    private enum DefaultsKey {
        static let lastVerifiedOnTimestamp = "grayscale_last_verified_on_timestamp"
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
        refreshFromSystem()
    }

    private func refreshFromSystem() {
        let currentState = UIAccessibility.isGrayscaleEnabled
        let now = Date()

        isGrayscaleEnabled = currentState

        if currentState {
            if activeRun == nil {
                beginVerifiedRun(at: now)
            } else {
                persistVerificationCheckpoint(at: now)
            }
        } else if let activeRun {
            let recoveredEnd = recoveredEndDate(for: activeRun, fallback: now)
            endVerifiedRun(at: recoveredEnd)
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

    private func rebuildSummaries(for days: Set<Date>) {
        guard !days.isEmpty else { return }

        let allRuns = (try? fetchAllRuns()) ?? []
        let completedRuns = allRuns.filter { !$0.isActive && $0.endTime != nil }
        let existingSummaries = (try? fetchAllSummaries()) ?? []
        var existingByDate = Dictionary(uniqueKeysWithValues: existingSummaries.map { ($0.date, $0) })

        for day in days {
            let snapshot = MetricsService.daySnapshot(
                for: day,
                runs: completedRuns,
                calendar: calendar,
                now: .now,
                includeActive: false
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
            summary.qualified = snapshot.qualified
            summary.perfect = snapshot.perfect

            if existingByDate[day] == nil {
                modelContext.insert(summary)
            }
        }
    }

    private func publishWidgetSnapshot(referenceDate: Date) {
        let runs = (try? fetchAllRuns()) ?? []
        let summaries = (try? fetchAllSummaries()) ?? []
        let mergedSnapshots = MetricsService.mergedDaySnapshots(
            summaries: summaries,
            runs: runs,
            calendar: calendar,
            now: referenceDate
        )

        let snapshot = WidgetSnapshot(
            isActive: isGrayscaleEnabled && activeRun != nil,
            activeRunStartTime: activeRun?.startTime,
            currentStreak: MetricsService.currentStreak(from: mergedSnapshots, calendar: calendar, today: referenceDate),
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
