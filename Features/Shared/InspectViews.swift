import SwiftUI

struct TactileSurfaceButtonStyle: ButtonStyle {
    var cornerRadius: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.988 : 1)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.04 : 0))
            )
            .shadow(color: .black.opacity(configuration.isPressed ? 0.3 : 0.2), radius: configuration.isPressed ? 18 : 14, x: 0, y: configuration.isPressed ? 14 : 10)
            .animation(.spring(response: 0.24, dampingFraction: 0.82), value: configuration.isPressed)
    }
}

struct DayDetailView: View {
    let snapshot: DayMetricsSnapshot
    let date: Date
    let timeline: DayTimelineSnapshot
    let goalSettings: GoalSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(date, format: .dateTime.month(.wide).day().year())
                        .font(.system(size: 22, weight: .light, design: .serif))
                        .foregroundStyle(.white)

                    Text(snapshot.status.title)
                        .font(.system(size: 30, weight: .medium, design: .serif))
                        .foregroundStyle(.white.opacity(0.96))
                }

                Spacer(minLength: 0)

                if let summaryText = MetricsService.summaryText(for: snapshot, goalSettings: goalSettings) {
                    StatusChip(text: summaryText)
                }
            }

            DayTimelineStrip(
                timeline: timeline,
                date: date,
                isPerfect: snapshot.isPerfect,
                progress: goalSettings.qualifyingProgress(
                    totalVerifiedSeconds: snapshot.totalVerifiedSeconds,
                    grayRate: snapshot.grayRate
                ),
                isActive: snapshot.totalVerifiedSeconds > 0
            )

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 18), count: 2), alignment: .leading, spacing: 18) {
                DetailMetric(title: "Gray Rate", value: percentString(snapshot.grayRate))
                DetailMetric(title: "Verified", value: DurationFormatter.statString(seconds: snapshot.totalVerifiedSeconds))
                DetailMetric(title: "Breaks", value: "\(snapshot.breakCount)")
                DetailMetric(title: "Relapse", value: DurationFormatter.statString(seconds: snapshot.relapseSeconds))
                DetailMetric(title: "Longest Run", value: DurationFormatter.statString(seconds: snapshot.longestRunSeconds))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(MonochromeTheme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.28), radius: 18, x: 0, y: 14)
        .contentTransition(.opacity)
    }

    private func percentString(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }
}

struct DayDetailSheetView: View {
    let snapshot: DayMetricsSnapshot
    let date: Date
    let timeline: DayTimelineSnapshot
    let goalSettings: GoalSettings

    var body: some View {
        ZStack {
            MonochromeTheme.background.ignoresSafeArea()
            MonochromeTheme.ambientGlow.ignoresSafeArea()

            ScrollView {
                DayDetailView(snapshot: snapshot, date: date, timeline: timeline, goalSettings: goalSettings)
                    .padding(20)
                    .padding(.top, 10)
            }
            .scrollIndicators(.hidden)
        }
    }
}

struct DetailMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .medium, design: .serif))
                .foregroundStyle(MonochromeTheme.tertiaryText)

            Text(value)
                .font(.system(size: 19, weight: .light, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct DayTimelineStrip: View {
    let timeline: DayTimelineSnapshot
    let date: Date
    let isPerfect: Bool
    let progress: Double
    let isActive: Bool
    private let calendar = Calendar.autoupdatingCurrent

    private var isToday: Bool {
        calendar.isDateInToday(date)
    }

    var body: some View {
        VStack(spacing: 12) {
            DayTimelineBar(
                timeline: timeline,
                isActive: isActive,
                markerOpacity: isToday ? 0.72 : 0.24,
                trackStrokeOpacity: isPerfect ? 0.14 : 0.08,
                showsFractureMarks: false,
                style: .detail,
                labels: DayTimelineLabels(leading: "12A", middle: "12P", trailing: isToday ? "Now" : "12A")
            )

            LineProgressRail(progress: progress, isActive: isActive, minimumProgress: 0)
                .frame(width: 112)
        }
    }
}

struct StatusChip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold, design: .serif))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.08))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
            )
    }
}
