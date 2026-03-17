import Foundation
import SwiftData

@Model
final class RunRecord {
    @Attribute(.unique) var id: UUID
    var startTime: Date
    var endTime: Date?
    var isActive: Bool
    var durationSecondsCached: Double

    init(
        id: UUID = UUID(),
        startTime: Date,
        endTime: Date? = nil,
        isActive: Bool = true,
        durationSecondsCached: Double = 0
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.isActive = isActive
        self.durationSecondsCached = durationSecondsCached
    }
}

@Model
final class DaySummary {
    @Attribute(.unique) var id: UUID
    var date: Date
    var totalVerifiedSeconds: Double
    var breakCount: Int
    var longestRunSeconds: Double
    var qualified: Bool
    var perfect: Bool

    init(
        id: UUID = UUID(),
        date: Date,
        totalVerifiedSeconds: Double = 0,
        breakCount: Int = 0,
        longestRunSeconds: Double = 0,
        qualified: Bool = false,
        perfect: Bool = false,
        calendar: Calendar = .autoupdatingCurrent
    ) {
        self.id = id
        self.date = calendar.startOfDay(for: date)
        self.totalVerifiedSeconds = totalVerifiedSeconds
        self.breakCount = breakCount
        self.longestRunSeconds = longestRunSeconds
        self.qualified = qualified
        self.perfect = perfect
    }
}
