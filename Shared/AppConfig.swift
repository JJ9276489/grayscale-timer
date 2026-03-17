import Foundation

enum AppConfig {
    static let qualifyingThresholdSeconds: TimeInterval = 21 * 60 * 60
    static let verificationCheckpointInterval: TimeInterval = 60
    static let heatmapDayCount = 90
    static let widgetKind = "GrayscaleTimerWidget"
    static let widgetRefreshInterval: TimeInterval = 15 * 60
    static let appGroupIdentifier = "group.com.jeraldyuan.GrayscaleTimer"
}
