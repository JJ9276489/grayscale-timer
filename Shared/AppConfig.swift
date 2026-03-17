import Foundation

enum AppConfig {
    static let defaultQualifyingThresholdSeconds: TimeInterval = 21 * 60 * 60
    static let defaultStrongThresholdSeconds: TimeInterval = 23 * 60 * 60
    static let defaultQualifyingRate = 0.70
    static let defaultStrongRate = 0.85
    static let defaultPerfectRequiresQualification = false
    static let defaultBreakDebounceSeconds: TimeInterval = 0
    static let verificationCheckpointInterval: TimeInterval = 60
    static let heatmapDayCount = 90
    static let widgetKind = "GrayscaleTimerWidget"
    static let widgetRefreshInterval: TimeInterval = 15 * 60
    static let appGroupIdentifier = "group.com.jeraldyuan.GrayscaleTimer"
}
