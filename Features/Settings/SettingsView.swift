import SwiftUI

struct SettingsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SettingsCard(title: "What Counts") {
                    Text("Only iOS-verified grayscale time counts. The app reads the official accessibility grayscale state, starts a run when grayscale turns on, and ends it when grayscale turns off. There are no manual timers or self-reported sessions.")
                }

                SettingsCard(title: "Local-Only Data") {
                    Text("Run records and day summaries are stored on-device with SwiftData. The widget reads a local snapshot from the shared app group. There is no backend, account, or network sync.")
                }

                SettingsCard(title: "Enable Grayscale") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("On iPhone:")
                        Text("Settings → Accessibility → Display & Text Size → Color Filters → On → Grayscale")
                            .foregroundStyle(.white)
                    }
                }

                SettingsCard(title: "Qualifying Threshold") {
                    Text("A qualifying day requires at least \(DurationFormatter.statString(seconds: AppConfig.qualifyingThresholdSeconds)) of verified grayscale time.")
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
}

private struct SettingsCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .serif))
                .foregroundStyle(MonochromeTheme.secondaryText)
                .textCase(.uppercase)
                .tracking(1.3)

            content
                .font(.system(size: 15, weight: .medium, design: .serif))
                .foregroundStyle(.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(MonochromeTheme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(MonochromeTheme.cardBorder, lineWidth: 1)
        )
    }
}
