import SwiftUI

struct RunTimerView: View {
    let activeRun: RunRecord?
    let isGrayscaleActive: Bool
    let currentOffStartTime: Date?
    let ringProgress: Double
    let isDamaged: Bool
    let isPristine: Bool
    let stateText: String
    let supportingText: String
    let isExpanded: Bool
    let expandedDetails: HeroExpandedDetails?
    let overlayDetail: HeroOverlayDetail?
    let showsOverlayDetail: Bool
    let onTap: () -> Void
    let onLongPress: () -> Void
    let referenceDate: Date

    @State private var animateSurface = false
    @State private var isPressed = false
    @State private var didLongPress = false

    private var displaySeconds: Double {
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
                .shadow(color: .black.opacity(0.5), radius: 30, x: 0, y: 24)

            VStack(spacing: 14) {
                ZStack {
                    HeroRingView(
                        progress: ringProgress,
                        isActive: isGrayscaleActive,
                        isDamaged: isDamaged,
                        isPristine: isPristine,
                        animateSurface: animateSurface,
                        isPressed: isPressed
                    )
                    .frame(width: 292, height: 292)

                    Text(DurationFormatter.clockString(seconds: displaySeconds))
                        .font(.system(size: 66, weight: .ultraLight, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.52)
                        .foregroundStyle(.white)
                        .contentTransition(.numericText(value: displaySeconds))
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
            .padding(.vertical, 46)

            if showsOverlayDetail, let overlayDetail {
                HeroOverlayPanel(detail: overlayDetail)
                    .padding(18)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .topLeading)))
                    .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: isExpanded ? 470 : 400)
        .scaleEffect(isPressed ? 0.988 : 1)
        .rotation3DEffect(.degrees(isPressed ? 1.5 : 0), axis: (x: 1, y: 0, z: 0))
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
        .onAppear {
            guard !animateSurface else { return }
            withAnimation(.easeInOut(duration: 5.8).repeatForever(autoreverses: true)) {
                animateSurface = true
            }
        }
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

private struct HeroRingView: View {
    let progress: Double
    let isActive: Bool
    let isDamaged: Bool
    let isPristine: Bool
    let animateSurface: Bool
    let isPressed: Bool

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(isActive ? 0.14 : 0.06),
                            Color.white.opacity(0.025),
                            .clear
                        ],
                        center: .center,
                        startRadius: 12,
                        endRadius: 172
                    )
                )
                .blur(radius: 16)
                .scaleEffect(animateSurface ? 1.015 : 0.985)
                .opacity(isPressed ? 1 : 0.88)

            Circle()
                .stroke(Color.white.opacity(isActive ? 0.09 : 0.05), style: StrokeStyle(lineWidth: 14, lineCap: .round))

            if clampedProgress > 0.001 {
                Circle()
                    .trim(from: 0, to: clampedProgress)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(isActive ? 0.96 : 0.42),
                                Color.white.opacity(isActive ? 0.28 : 0.16)
                            ],
                            startPoint: .top,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 14, lineCap: isDamaged ? .butt : .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .shadow(color: .white.opacity(isActive ? 0.14 : 0.04), radius: isActive ? 8 : 2, x: 0, y: 0)
            }

            if isDamaged {
                RingScar()
            }

            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(coreTopOpacity),
                            Color.white.opacity(coreMidOpacity),
                            Color.black.opacity(coreBottomOpacity)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .padding(38)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(isActive ? 0.1 : 0.05), lineWidth: 1)
                        .padding(38)
                )
                .overlay {
                    if !isActive {
                        Circle()
                            .fill(Color.black.opacity(0.42))
                            .padding(76)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
                                    .padding(76)
                            )
                    }
                }
                .scaleEffect(isPressed ? 0.985 : 1)

            if isDamaged {
                CoreScar()
                    .padding(76)
            }
        }
        .opacity(isActive ? 1 : 0.86)
    }

    private var coreTopOpacity: Double {
        if !isActive { return 0.06 }
        if isPristine { return 0.16 }
        return 0.12
    }

    private var coreMidOpacity: Double {
        if !isActive { return 0.03 }
        if isPristine { return 0.08 }
        return 0.05
    }

    private var coreBottomOpacity: Double {
        if !isActive { return 0.62 }
        return isDamaged ? 0.42 : 0.32
    }
}

private struct RingScar: View {
    var body: some View {
        Circle()
            .trim(from: 0.12, to: 0.17)
            .stroke(
                Color.black.opacity(0.74),
                style: StrokeStyle(lineWidth: 18, lineCap: .round)
            )
            .rotationEffect(.degrees(-90))
            .overlay(
                Circle()
                    .trim(from: 0.119, to: 0.171)
                    .stroke(Color.white.opacity(0.12), style: StrokeStyle(lineWidth: 1))
                    .rotationEffect(.degrees(-90))
            )
    }
}

private struct CoreScar: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(Color.black.opacity(0.66))
            .frame(width: 40, height: 8)
            .overlay(
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .stroke(Color.white.opacity(0.09), lineWidth: 1)
            )
            .rotationEffect(.degrees(-28))
            .offset(x: 32, y: -26)
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
                .fill(Color.white.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.28), radius: 16, x: 0, y: 12)
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
        ringProgress: 0.78,
        isDamaged: false,
        isPristine: true,
        stateText: "Line intact",
        supportingText: "Verified uninterrupted grayscale time",
        isExpanded: true,
        expandedDetails: HeroExpandedDetails(
            grayRateText: "78%",
            verifiedText: "11h 40m",
            breaksText: "1",
            relapseText: "1h 00m"
        ),
        overlayDetail: HeroOverlayDetail(
            title: "Started 9:03 PM",
            subtitle: "Perfect still intact",
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
        ringProgress: 0.41,
        isDamaged: true,
        isPristine: false,
        stateText: "Out of grayscale",
        supportingText: "Use Side Button Triple-Click",
        isExpanded: false,
        expandedDetails: nil,
        overlayDetail: HeroOverlayDetail(
            title: "Use Side Button Triple-Click",
            subtitle: "Return now to recover pace.",
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
