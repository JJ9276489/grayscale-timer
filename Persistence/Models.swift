import Foundation
import SwiftData

@Model
final class RunRecord {
    @Attribute(.unique) var id: UUID
    var startTime: Date
    var endTime: Date?
    var isActive: Bool
    var durationSecondsCached: Double
    var observedBreak: Bool?

    init(
        id: UUID = UUID(),
        startTime: Date,
        endTime: Date? = nil,
        isActive: Bool = true,
        durationSecondsCached: Double = 0,
        observedBreak: Bool? = nil
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.isActive = isActive
        self.durationSecondsCached = durationSecondsCached
        self.observedBreak = observedBreak
    }
}

@Model
final class DaySummary {
    @Attribute(.unique) var id: UUID
    var date: Date
    var totalVerifiedSeconds: Double
    var totalUnverifiedSeconds: Double?
    var breakCount: Int
    var longestRunSeconds: Double
    var qualified: Bool
    var perfect: Bool

    init(
        id: UUID = UUID(),
        date: Date,
        totalVerifiedSeconds: Double = 0,
        totalUnverifiedSeconds: Double = 0,
        breakCount: Int = 0,
        longestRunSeconds: Double = 0,
        qualified: Bool = false,
        perfect: Bool = false,
        calendar: Calendar = .autoupdatingCurrent
    ) {
        self.id = id
        self.date = calendar.startOfDay(for: date)
        self.totalVerifiedSeconds = totalVerifiedSeconds
        self.totalUnverifiedSeconds = totalUnverifiedSeconds
        self.breakCount = breakCount
        self.longestRunSeconds = longestRunSeconds
        self.qualified = qualified
        self.perfect = perfect
    }
}

@Model
final class UnverifiedInterval {
    @Attribute(.unique) var id: UUID
    var startTime: Date
    var endTime: Date?

    init(
        id: UUID = UUID(),
        startTime: Date,
        endTime: Date? = nil
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
    }
}
