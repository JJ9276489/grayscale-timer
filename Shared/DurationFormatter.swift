import Foundation

enum DurationFormatter {
    static func clockString(seconds: Double) -> String {
        let clamped = max(0, Int(seconds.rounded(.down)))
        let hours = clamped / 3_600
        let minutes = (clamped % 3_600) / 60
        let secs = clamped % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, secs)
    }

    static func compactString(seconds: Double) -> String {
        let clamped = max(0, Int(seconds.rounded(.down)))
        let hours = clamped / 3_600
        let minutes = (clamped % 3_600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }

        let secs = clamped % 60
        if minutes > 0 {
            return "\(minutes)m \(secs)s"
        }

        return "\(secs)s"
    }

    static func statString(seconds: Double) -> String {
        let clamped = max(0, Int(seconds.rounded(.down)))
        let hours = clamped / 3_600
        let minutes = (clamped % 3_600) / 60

        if hours >= 24 {
            let days = hours / 24
            let remainingHours = hours % 24
            return "\(days)d \(remainingHours)h"
        }

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }

        return "\(minutes)m"
    }
}
