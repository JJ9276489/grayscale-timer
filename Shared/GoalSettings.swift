import Foundation

enum GoalMode: String, CaseIterable, Identifiable {
    case percentage
    case fixedHours

    var id: String { rawValue }

    var title: String {
        switch self {
        case .percentage:
            return "Percentage"
        case .fixedHours:
            return "Fixed Hours"
        }
    }
}

enum BreakDebounceOption: Double, CaseIterable, Identifiable {
    case immediate = 0
    case fifteenSeconds = 15
    case sixtySeconds = 60

    var id: Double { rawValue }

    var title: String {
        switch self {
        case .immediate:
            return "Immediate"
        case .fifteenSeconds:
            return "15 Seconds"
        case .sixtySeconds:
            return "60 Seconds"
        }
    }

    var subtitle: String {
        switch self {
        case .immediate:
            return "Every off transition ends the run."
        case .fifteenSeconds:
            return "Ignore very short accidental toggles."
        case .sixtySeconds:
            return "Only count sustained time out of grayscale."
        }
    }
}

enum QuickReturnMethod: String, CaseIterable, Identifiable {
    case accessibilityShortcut
    case actionButton
    case backTap
    case controlCenter

    var id: String { rawValue }

    var title: String {
        switch self {
        case .accessibilityShortcut:
            return "Accessibility Shortcut"
        case .actionButton:
            return "Action Button"
        case .backTap:
            return "Back Tap"
        case .controlCenter:
            return "Control Center"
        }
    }

    var tagTitle: String {
        switch self {
        case .accessibilityShortcut:
            return "Best"
        case .actionButton:
            return "Fast if supported"
        case .backTap:
            return "Convenient"
        case .controlCenter:
            return "Fallback"
        }
    }

    var subtitle: String {
        switch self {
        case .accessibilityShortcut:
            return "Best overall for most users."
        case .actionButton:
            return "Fast on supported iPhones."
        case .backTap:
            return "Convenient if you prefer a gesture."
        case .controlCenter:
            return "Reliable when hardware controls are occupied."
        }
    }

    var summary: String {
        switch self {
        case .accessibilityShortcut:
            return "One hardware gesture back to grayscale."
        case .actionButton:
            return "A dedicated hardware press for recovery."
        case .backTap:
            return "A quick device gesture when buttons are busy."
        case .controlCenter:
            return "Universal fallback without special hardware."
        }
    }

    var instruction: String {
        switch self {
        case .accessibilityShortcut:
            return "Assign Color Filters to Side Button Triple-Click."
        case .actionButton:
            return "Set the Action Button to Accessibility Shortcut, then include Color Filters."
        case .backTap:
            return "Map Double Tap or Triple Tap to Accessibility Shortcut."
        case .controlCenter:
            return "Add Accessibility Shortcuts to Control Center for quick recovery."
        }
    }

    var settingsPaths: [String] {
        switch self {
        case .accessibilityShortcut:
            return [
                "Settings → Accessibility → Accessibility Shortcut → Color Filters"
            ]
        case .actionButton:
            return [
                "Settings → Action Button → Accessibility Shortcut",
                "Then: Settings → Accessibility → Accessibility Shortcut → Color Filters"
            ]
        case .backTap:
            return [
                "Settings → Accessibility → Touch → Back Tap → Accessibility Shortcut",
                "Then: Settings → Accessibility → Accessibility Shortcut → Color Filters"
            ]
        case .controlCenter:
            return [
                "Settings → Control Center → add Accessibility Shortcuts",
                "Then ensure Accessibility Shortcuts includes Color Filters"
            ]
        }
    }

    var homePrompt: String {
        switch self {
        case .accessibilityShortcut:
            return "Use Side Button Triple-Click"
        case .actionButton:
            return "Use Action Button"
        case .backTap:
            return "Use Back Tap"
        case .controlCenter:
            return "Open Control Center"
        }
    }

    var isRecommended: Bool {
        self == .accessibilityShortcut
    }
}

struct GoalSettings: Equatable, Hashable {
    var mode: GoalMode
    var qualifyingRate: Double
    var strongRate: Double
    var fixedQualifyingHours: Double
    var fixedStrongHours: Double
    var perfectRequiresQualification: Bool
    var breakDebounceSeconds: TimeInterval

    static let `default` = GoalSettings(
        mode: .percentage,
        qualifyingRate: AppConfig.defaultQualifyingRate,
        strongRate: AppConfig.defaultStrongRate,
        fixedQualifyingHours: AppConfig.defaultQualifyingThresholdSeconds / 3_600,
        fixedStrongHours: AppConfig.defaultStrongThresholdSeconds / 3_600,
        perfectRequiresQualification: AppConfig.defaultPerfectRequiresQualification,
        breakDebounceSeconds: AppConfig.defaultBreakDebounceSeconds
    )

    var fixedQualifyingSeconds: Double { fixedQualifyingHours * 3_600 }
    var fixedStrongSeconds: Double { fixedStrongHours * 3_600 }

    func isQualifying(totalVerifiedSeconds: Double, grayRate: Double) -> Bool {
        switch mode {
        case .percentage:
            return grayRate >= qualifyingRate
        case .fixedHours:
            return totalVerifiedSeconds >= fixedQualifyingSeconds
        }
    }

    func isStrong(totalVerifiedSeconds: Double, grayRate: Double) -> Bool {
        switch mode {
        case .percentage:
            return grayRate >= strongRate
        case .fixedHours:
            return totalVerifiedSeconds >= fixedStrongSeconds
        }
    }
}

extension GoalSettings {
    func qualifyingProgress(totalVerifiedSeconds: Double, grayRate: Double) -> Double {
        switch mode {
        case .percentage:
            guard qualifyingRate > 0 else { return 0 }
            return min(max(grayRate / qualifyingRate, 0), 1)
        case .fixedHours:
            guard fixedQualifyingSeconds > 0 else { return 0 }
            return min(max(totalVerifiedSeconds / fixedQualifyingSeconds, 0), 1)
        }
    }
}

enum GoalSettingsStore {
    enum Key {
        static let goalMode = "goal_mode"
        static let qualifyingRate = "goal_qualifying_rate"
        static let strongRate = "goal_strong_rate"
        static let fixedQualifyingHours = "goal_fixed_qualifying_hours"
        static let fixedStrongHours = "goal_fixed_strong_hours"
        static let perfectRequiresQualification = "goal_perfect_requires_qualification"
        static let breakDebounceSeconds = "goal_break_debounce_seconds"
        static let quickReturnMethod = "goal_quick_return_method"
    }

    static func load(userDefaults: UserDefaults = .standard) -> GoalSettings {
        let defaults = GoalSettings.default

        let mode = GoalMode(rawValue: userDefaults.string(forKey: Key.goalMode) ?? defaults.mode.rawValue) ?? defaults.mode
        let qualifyingRate = clampedRate(
            userDefaults.object(forKey: Key.qualifyingRate) as? Double ?? defaults.qualifyingRate
        )
        let strongRate = max(
            qualifyingRate,
            clampedRate(userDefaults.object(forKey: Key.strongRate) as? Double ?? defaults.strongRate)
        )
        let fixedQualifyingHours = clampedHours(
            userDefaults.object(forKey: Key.fixedQualifyingHours) as? Double ?? defaults.fixedQualifyingHours
        )
        let fixedStrongHours = max(
            fixedQualifyingHours,
            clampedHours(userDefaults.object(forKey: Key.fixedStrongHours) as? Double ?? defaults.fixedStrongHours)
        )
        let perfectRequiresQualification = userDefaults.object(forKey: Key.perfectRequiresQualification) as? Bool
            ?? defaults.perfectRequiresQualification
        let breakDebounceSeconds = normalizedDebounce(
            userDefaults.object(forKey: Key.breakDebounceSeconds) as? Double ?? defaults.breakDebounceSeconds
        )

        return GoalSettings(
            mode: mode,
            qualifyingRate: qualifyingRate,
            strongRate: strongRate,
            fixedQualifyingHours: fixedQualifyingHours,
            fixedStrongHours: fixedStrongHours,
            perfectRequiresQualification: perfectRequiresQualification,
            breakDebounceSeconds: breakDebounceSeconds
        )
    }

    static func normalizedDebounce(_ seconds: Double) -> TimeInterval {
        BreakDebounceOption(rawValue: seconds)?.rawValue ?? GoalSettings.default.breakDebounceSeconds
    }

    private static func clampedRate(_ value: Double) -> Double {
        min(max(value, 0.1), 0.99)
    }

    private static func clampedHours(_ value: Double) -> Double {
        min(max(value, 1), 24)
    }
}
