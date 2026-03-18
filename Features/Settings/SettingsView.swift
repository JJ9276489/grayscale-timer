import SwiftUI

struct SettingsView: View {
    @AppStorage(GoalSettingsStore.Key.goalMode) private var goalModeRawValue = GoalMode.percentage.rawValue
    @AppStorage(GoalSettingsStore.Key.qualifyingRate) private var qualifyingRate = AppConfig.defaultQualifyingRate
    @AppStorage(GoalSettingsStore.Key.strongRate) private var strongRate = AppConfig.defaultStrongRate
    @AppStorage(GoalSettingsStore.Key.fixedQualifyingHours) private var fixedQualifyingHours = AppConfig.defaultQualifyingThresholdSeconds / 3_600
    @AppStorage(GoalSettingsStore.Key.fixedStrongHours) private var fixedStrongHours = AppConfig.defaultStrongThresholdSeconds / 3_600
    @AppStorage(GoalSettingsStore.Key.perfectRequiresQualification) private var perfectRequiresQualification = AppConfig.defaultPerfectRequiresQualification
    @AppStorage(GoalSettingsStore.Key.breakDebounceSeconds) private var breakDebounceSeconds = AppConfig.defaultBreakDebounceSeconds

    @State private var showDefinitions = false

    private var goalMode: GoalMode {
        GoalMode(rawValue: goalModeRawValue) ?? .percentage
    }

    private var selectedDebounceOption: BreakDebounceOption {
        BreakDebounceOption(rawValue: breakDebounceSeconds) ?? .immediate
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                CompactSettingsSurface(title: "Controls") {
                    VStack(alignment: .leading, spacing: 16) {
                        Picker("Goal Mode", selection: $goalModeRawValue) {
                            ForEach(GoalMode.allCases) { mode in
                                Text(mode.title).tag(mode.rawValue)
                            }
                        }
                        .pickerStyle(.segmented)

                        if goalMode == .percentage {
                            VStack(alignment: .leading, spacing: 12) {
                                ThresholdControlRow(
                                    title: "Qualifying",
                                    value: percentString(qualifyingRate),
                                    onDecrease: { adjustQualifyingRate(by: -0.05) },
                                    onIncrease: { adjustQualifyingRate(by: 0.05) }
                                )

                                ThresholdControlRow(
                                    title: "Strong",
                                    value: percentString(strongRate),
                                    onDecrease: { adjustStrongRate(by: -0.05) },
                                    onIncrease: { adjustStrongRate(by: 0.05) }
                                )
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 12) {
                                ThresholdControlRow(
                                    title: "Qualifying",
                                    value: hourString(fixedQualifyingHours),
                                    onDecrease: { adjustFixedQualifyingHours(by: -0.5) },
                                    onIncrease: { adjustFixedQualifyingHours(by: 0.5) }
                                )

                                ThresholdControlRow(
                                    title: "Strong",
                                    value: hourString(fixedStrongHours),
                                    onDecrease: { adjustFixedStrongHours(by: -0.5) },
                                    onIncrease: { adjustFixedStrongHours(by: 0.5) }
                                )
                            }
                        }

                        Toggle("Perfect day requires qualification", isOn: $perfectRequiresQualification)
                            .toggleStyle(.switch)
                            .tint(.white)

                        Divider()
                            .overlay(Color.white.opacity(0.08))

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Break Handling")
                                .font(.system(size: 12, weight: .medium, design: .serif))
                                .foregroundStyle(MonochromeTheme.secondaryText)

                            Picker("Break Handling", selection: $breakDebounceSeconds) {
                                Text("Now").tag(BreakDebounceOption.immediate.rawValue)
                                Text("15s").tag(BreakDebounceOption.fifteenSeconds.rawValue)
                                Text("60s").tag(BreakDebounceOption.sixtySeconds.rawValue)
                            }
                            .pickerStyle(.segmented)

                            Text(selectedDebounceOption.subtitle)
                                .font(.system(size: 12, weight: .medium, design: .serif))
                                .foregroundStyle(MonochromeTheme.tertiaryText)
                        }
                    }
                }

                CompactSettingsSurface(title: "Enable Grayscale") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("No direct jump is available for Color Filters.")
                            .font(.system(size: 13, weight: .medium, design: .serif))
                            .foregroundStyle(MonochromeTheme.secondaryText)

                        Text("Accessibility → Display & Text Size → Color Filters → Grayscale")
                            .font(.system(size: 15, weight: .medium, design: .serif))
                            .foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("Turn Color Filters on, then choose Grayscale.")
                            .font(.system(size: 12, weight: .medium, design: .serif))
                            .foregroundStyle(MonochromeTheme.tertiaryText)
                    }
                }

                CompactSettingsSurface(title: "About") {
                    DisclosureGroup(isExpanded: $showDefinitions) {
                        VStack(alignment: .leading, spacing: 14) {
                            DefinitionRow(title: "Verified Time", detail: "Recorded from grayscale-on runs the app observes and reconciles from the current iOS state.")
                            DefinitionRow(title: "Gray Rate", detail: "Verified grayscale divided by elapsed local day time. Past days use the full local calendar day.")
                            DefinitionRow(title: "Break", detail: "A verified off transition after the selected debounce interval.")
                            DefinitionRow(title: "Relapse Time", detail: "Time outside grayscale after the first verified grayscale time on that day.")
                            DefinitionRow(title: "Qualifying Day", detail: qualifyingDefinition)
                            DefinitionRow(title: "Perfect Day", detail: perfectDefinition)

                            Text("iOS does not provide a historical grayscale event feed while the app is suspended.")
                                .font(.system(size: 12, weight: .medium, design: .serif))
                                .foregroundStyle(MonochromeTheme.secondaryText)

                            Text("Local only. No backend, account, or analytics.")
                                .font(.system(size: 12, weight: .medium, design: .serif))
                                .foregroundStyle(MonochromeTheme.tertiaryText)
                        }
                        .padding(.top, 12)
                    } label: {
                        Text("What counts")
                            .font(.system(size: 15, weight: .medium, design: .serif))
                            .foregroundStyle(.white)
                    }
                    .tint(.white)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 30)
        }
        .scrollIndicators(.hidden)
        .background(MonochromeTheme.background.ignoresSafeArea())
        .navigationTitle("Settings")
        .toolbarTitleDisplayMode(.inline)
    }

    private var qualifyingDefinition: String {
        switch goalMode {
        case .percentage:
            return "Gray rate at or above \(percentString(qualifyingRate))."
        case .fixedHours:
            return "Verified grayscale at or above \(hourString(fixedQualifyingHours))."
        }
    }

    private var perfectDefinition: String {
        if perfectRequiresQualification {
            return "Zero verified breaks, plus the day must still qualify."
        }

        return "Zero verified breaks on a day with at least some verified grayscale time."
    }

    private func adjustQualifyingRate(by delta: Double) {
        qualifyingRate = min(max(qualifyingRate + delta, 0.10), 0.99)
        strongRate = max(strongRate, qualifyingRate)
    }

    private func adjustStrongRate(by delta: Double) {
        strongRate = min(max(strongRate + delta, qualifyingRate), 0.99)
    }

    private func adjustFixedQualifyingHours(by delta: Double) {
        fixedQualifyingHours = min(max(fixedQualifyingHours + delta, 1), 24)
        fixedStrongHours = max(fixedStrongHours, fixedQualifyingHours)
    }

    private func adjustFixedStrongHours(by delta: Double) {
        fixedStrongHours = min(max(fixedStrongHours + delta, fixedQualifyingHours), 24)
    }

    private func percentString(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    private func hourString(_ value: Double) -> String {
        if value.rounded() == value {
            return "\(Int(value))h"
        }

        return "\(String(format: "%.1f", value))h"
    }
}

private struct DefinitionRow: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .serif))
                .foregroundStyle(.white)

            Text(detail)
                .font(.system(size: 12, weight: .medium, design: .serif))
                .foregroundStyle(MonochromeTheme.secondaryText)
        }
    }
}

private struct ThresholdControlRow: View {
    let title: String
    let value: String
    let onDecrease: () -> Void
    let onIncrease: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .serif))
                    .foregroundStyle(.white)

                Text(value)
                    .font(.system(size: 24, weight: .light, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(MonochromeTheme.secondaryText)
            }

            Spacer()

            HStack(spacing: 10) {
                AdjustmentButton(systemName: "minus", action: onDecrease)
                AdjustmentButton(systemName: "plus", action: onIncrease)
            }
        }
    }
}

private struct AdjustmentButton: View {
    let systemName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.08))
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct CompactSettingsSurface<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 12, weight: .medium, design: .serif))
                .foregroundStyle(MonochromeTheme.secondaryText)

            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(MonochromeTheme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.22), radius: 14, x: 0, y: 12)
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .preferredColorScheme(.dark)
}
