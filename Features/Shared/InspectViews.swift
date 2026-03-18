import SwiftUI

struct TactileSurfaceButtonStyle: ButtonStyle {
    var cornerRadius: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .rotation3DEffect(.degrees(configuration.isPressed ? 1.8 : 0), axis: (x: 1, y: 0, z: 0))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.05 : 0))
            )
            .shadow(color: .black.opacity(configuration.isPressed ? 0.34 : 0.22), radius: configuration.isPressed ? 24 : 18, x: 0, y: configuration.isPressed ? 18 : 12)
            .animation(.spring(response: 0.24, dampingFraction: 0.82), value: configuration.isPressed)
    }
}

struct DayDetailView: View {
    let snapshot: DayMetricsSnapshot
    let date: Date
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

            ContinuityStrip(snapshot: snapshot)

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
    let goalSettings: GoalSettings

    var body: some View {
        ZStack {
            MonochromeTheme.background.ignoresSafeArea()
            MonochromeTheme.ambientGlow.ignoresSafeArea()

            ScrollView {
                DayDetailView(snapshot: snapshot, date: date, goalSettings: goalSettings)
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

struct ContinuityStrip: View {
    let snapshot: DayMetricsSnapshot

    var body: some View {
        GeometryReader { geometry in
            let rawFillWidth = geometry.size.width * snapshot.grayRate
            let fillWidth = snapshot.grayRate > 0 ? max(12, rawFillWidth) : 0

            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.06))

                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.8),
                                Color.white.opacity(0.22)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: fillWidth)

                HStack(spacing: 4) {
                    ForEach(0..<min(snapshot.breakCount, 6), id: \.self) { _ in
                        Capsule(style: .continuous)
                            .fill(Color.black.opacity(0.55))
                            .frame(width: 3, height: 12)
                    }
                }
                .padding(.leading, 10)
                .opacity(snapshot.breakCount > 0 ? 1 : 0)
            }
        }
        .frame(height: 16)
        .overlay(
            Capsule(style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
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
