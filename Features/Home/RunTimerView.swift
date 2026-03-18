import SwiftUI

struct RunTimerView: View {
    let activeRun: RunRecord?
    let isGrayscaleActive: Bool
    let currentOffStartTime: Date?
    let qualifyingProgress: Double
    let timeline: DayTimelineSnapshot
    let stateText: String
    let supportingText: String
    let isExpanded: Bool
    let expandedDetails: HeroExpandedDetails?
    let overlayDetail: HeroOverlayDetail?
    let showsOverlayDetail: Bool
    let onTap: () -> Void
    let onLongPress: () -> Void
    let referenceDate: Date

    @State private var isPressed = false
    @State private var didLongPress = false

    private func displaySeconds(at referenceDate: Date) -> Double {
        if isGrayscaleActive, let activeRun {
            return max(0, referenceDate.timeIntervalSince(activeRun.startTime))
        }

        if let currentOffStartTime {
            return max(0, referenceDate.timeIntervalSince(currentOffStartTime))
        }

        return 0
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(MonochromeTheme.liveBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .stroke(MonochromeTheme.liveBorder, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.42), radius: 26, x: 0, y: 20)

            VStack(spacing: 18) {
                HeroTimelineView(
                    timeline: timeline,
                    qualifyingProgress: qualifyingProgress,
                    isActive: isGrayscaleActive,
                    isPressed: isPressed
                )

                TimelineView(.periodic(from: referenceDate, by: (isGrayscaleActive || currentOffStartTime != nil) ? 1 : 60)) { context in
                    let seconds = displaySeconds(at: context.date)

                    Text(DurationFormatter.clockString(seconds: seconds))
                        .font(.system(size: 70, weight: .ultraLight, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.52)
                        .foregroundStyle(.white)
                        .contentTransition(.numericText(value: seconds))
                }

                Text(stateText)
                    .font(.system(size: 20, weight: .medium, design: .serif))
                    .foregroundStyle(.white.opacity(isGrayscaleActive ? 0.96 : 0.88))

                Text(supportingText)
                    .font(.system(size: 12, weight: .medium, design: .serif))
                    .foregroundStyle(MonochromeTheme.secondaryText)
                    .tracking(0.2)

                if isExpanded, let expandedDetails {
                    Divider()
                        .overlay(Color.white.opacity(0.08))
                        .padding(.top, 8)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 2), alignment: .leading, spacing: 14) {
                        HeroInlineMetric(title: "Gray Rate", value: expandedDetails.grayRateText)
                        HeroInlineMetric(title: "Verified", value: expandedDetails.verifiedText)
                        HeroInlineMetric(title: "Breaks", value: expandedDetails.breaksText)
                        HeroInlineMetric(title: "Relapse", value: expandedDetails.relapseText)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 40)

            if showsOverlayDetail, let overlayDetail {
                HeroOverlayPanel(detail: overlayDetail)
                    .padding(.horizontal, 22)
                    .offset(y: -16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
                    .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: isExpanded ? 410 : 330)
        .scaleEffect(isPressed ? 0.988 : 1)
        .overlay(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .stroke(Color.white.opacity(isPressed ? 0.2 : 0), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
        .onTapGesture {
            if didLongPress {
                didLongPress = false
                return
            }
            withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                onTap()
            }
        }
        .onLongPressGesture(minimumDuration: 0.5, perform: {
            didLongPress = true
            onLongPress()
        }, onPressingChanged: { pressing in
            withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
                isPressed = pressing
            }
        })
        .animation(.spring(response: 0.34, dampingFraction: 0.86), value: isExpanded)
        .animation(.spring(response: 0.42, dampingFraction: 0.88), value: isGrayscaleActive)
        .animation(.spring(response: 0.42, dampingFraction: 0.88), value: stateText)
    }
}

struct HeroExpandedDetails {
    let grayRateText: String
    let verifiedText: String
    let breaksText: String
    let relapseText: String
}

struct HeroOverlayDetail {
    let title: String
    let subtitle: String
    let footnote: String?
}

private struct HeroTimelineView: View {
    let timeline: DayTimelineSnapshot
    let qualifyingProgress: Double
    let isActive: Bool
    let isPressed: Bool

    var body: some View {
        VStack(spacing: 14) {
            DayTimelineBar(
                timeline: timeline,
                isActive: isActive,
                markerOpacity: isActive ? 0.85 : 0.28,
                trackStrokeOpacity: isActive ? 0.1 : 0.07,
                showsFractureMarks: false,
                showsCurrentDot: isActive,
                style: .hero,
                labels: DayTimelineLabels(leading: "12A", middle: "12P", trailing: "Now"),
                markerLabel: nil
            )

            qualifyingRail
        }
        .opacity(isActive ? 1 : 0.84)
        .padding(.top, 2)
        .overlay(alignment: .top) {
            if isActive {
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(isPressed ? 0.12 : 0.08))
                    .frame(width: 88, height: 1)
                    .blur(radius: 0.4)
            }
        }
    }

    private var qualifyingRail: some View {
        LineProgressRail(progress: qualifyingProgress, isActive: isActive)
            .frame(width: 126)
            .opacity(isPressed ? 0.82 : 1)
    }
}

private struct HeroOverlayPanel: View {
    let detail: HeroOverlayDetail

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(detail.title)
                .font(.system(size: 13, weight: .semibold, design: .serif))
                .foregroundStyle(.white)

            Text(detail.subtitle)
                .font(.system(size: 12, weight: .medium, design: .serif))
                .foregroundStyle(MonochromeTheme.secondaryText)

            if let footnote = detail.footnote {
                Text(footnote)
                    .font(.system(size: 11, weight: .medium, design: .serif))
                    .foregroundStyle(MonochromeTheme.tertiaryText)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(0.76))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.34), radius: 18, x: 0, y: 14)
    }
}

private struct HeroInlineMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .medium, design: .serif))
                .foregroundStyle(MonochromeTheme.tertiaryText)

            Text(value)
                .font(.system(size: 18, weight: .light, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
        }
    }
}

#Preview("Run Timer - Active") {
    RunTimerView(
        activeRun: RunRecord(startTime: .now.addingTimeInterval(-14_400), isActive: true),
        isGrayscaleActive: true,
        currentOffStartTime: nil,
        qualifyingProgress: 0.78,
        timeline: DayTimelineSnapshot(
            segments: [
                DayTimelineSegment(startFraction: 0.14, endFraction: 0.46),
                DayTimelineSegment(startFraction: 0.58, endFraction: 0.89)
            ],
            breakFractions: [0.46],
            currentFraction: 0.89
        ),
        stateText: "Line intact",
        supportingText: "Verified uninterrupted run",
        isExpanded: true,
        expandedDetails: HeroExpandedDetails(
            grayRateText: "78%",
            verifiedText: "11h 40m",
            breaksText: "1",
            relapseText: "1h 00m"
        ),
        overlayDetail: HeroOverlayDetail(
            title: "Started 9:03 PM",
            subtitle: "Line still intact",
            footnote: "Verified today 11h 40m"
        ),
        showsOverlayDetail: true,
        onTap: {},
        onLongPress: {},
        referenceDate: .now
    )
    .padding(20)
    .background(MonochromeTheme.background)
    .preferredColorScheme(.dark)
}

#Preview("Run Timer - Off") {
    RunTimerView(
        activeRun: nil,
        isGrayscaleActive: false,
        currentOffStartTime: .now.addingTimeInterval(-2_100),
        qualifyingProgress: 0.41,
        timeline: DayTimelineSnapshot(
            segments: [
                DayTimelineSegment(startFraction: 0.18, endFraction: 0.38),
                DayTimelineSegment(startFraction: 0.52, endFraction: 0.69)
            ],
            breakFractions: [0.38, 0.69],
            currentFraction: 0.87
        ),
        stateText: "Break open",
        supportingText: "Color is live now",
        isExpanded: false,
        expandedDetails: nil,
        overlayDetail: HeroOverlayDetail(
            title: "Break open",
            subtitle: "Restore the line",
            footnote: "Out since 9:21 PM"
        ),
        showsOverlayDetail: false,
        onTap: {},
        onLongPress: {},
        referenceDate: .now
    )
    .padding(20)
    .background(MonochromeTheme.background)
    .preferredColorScheme(.dark)
}
