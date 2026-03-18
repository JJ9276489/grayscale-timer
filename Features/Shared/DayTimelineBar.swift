import SwiftUI

struct DayTimelineLabels {
    let leading: String
    let middle: String
    let trailing: String
}

struct DayTimelineBarStyle {
    let trackHeight: CGFloat
    let segmentHeight: CGFloat
    let trackYOffset: CGFloat
    let segmentYOffset: CGFloat
    let fractureYOffset: CGFloat
    let markerYOffset: CGFloat
    let markerHeight: CGFloat
    let fractureSize: CGSize
    let fractureLineWidth: CGFloat
    let segmentShadowOpacity: Double
    let segmentShadowRadius: CGFloat
    let strokeOpacity: Double
    let trackFrameHeight: CGFloat
    let labelSpacing: CGFloat
    let labelFontSize: CGFloat

    static let hero = DayTimelineBarStyle(
        trackHeight: 4,
        segmentHeight: 6,
        trackYOffset: 12,
        segmentYOffset: 11,
        fractureYOffset: 6,
        markerYOffset: 1,
        markerHeight: 22,
        fractureSize: CGSize(width: 18, height: 14),
        fractureLineWidth: 2.4,
        segmentShadowOpacity: 0.1,
        segmentShadowRadius: 8,
        strokeOpacity: 0.1,
        trackFrameHeight: 32,
        labelSpacing: 8,
        labelFontSize: 10
    )

    static let detail = DayTimelineBarStyle(
        trackHeight: 4,
        segmentHeight: 6,
        trackYOffset: 0,
        segmentYOffset: -1,
        fractureYOffset: -5,
        markerYOffset: -7,
        markerHeight: 18,
        fractureSize: CGSize(width: 16, height: 14),
        fractureLineWidth: 2,
        segmentShadowOpacity: 0.08,
        segmentShadowRadius: 6,
        strokeOpacity: 0.08,
        trackFrameHeight: 16,
        labelSpacing: 8,
        labelFontSize: 10
    )
}

struct DayTimelineBar: View {
    let timeline: DayTimelineSnapshot
    let isActive: Bool
    let markerOpacity: Double
    let trackStrokeOpacity: Double
    let showsFractureMarks: Bool
    let showsCurrentDot: Bool
    let style: DayTimelineBarStyle
    let labels: DayTimelineLabels?
    let markerLabel: String?

    init(
        timeline: DayTimelineSnapshot,
        isActive: Bool,
        markerOpacity: Double,
        trackStrokeOpacity: Double? = nil,
        showsFractureMarks: Bool = true,
        showsCurrentDot: Bool = false,
        style: DayTimelineBarStyle,
        labels: DayTimelineLabels? = nil,
        markerLabel: String? = nil
    ) {
        self.timeline = timeline
        self.isActive = isActive
        self.markerOpacity = markerOpacity
        self.trackStrokeOpacity = trackStrokeOpacity ?? style.strokeOpacity
        self.showsFractureMarks = showsFractureMarks
        self.showsCurrentDot = showsCurrentDot
        self.style = style
        self.labels = labels
        self.markerLabel = markerLabel
    }

    var body: some View {
        VStack(spacing: style.labelSpacing) {
            GeometryReader { proxy in
                let safeWidth = proxy.size.width
                let currentX = safeWidth * CGFloat(timeline.currentFraction)
                let labelHalfWidth: CGFloat = 34
                let bubbleX = min(max(currentX, labelHalfWidth), safeWidth - labelHalfWidth)

                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(isActive ? 0.08 : 0.04))
                        .frame(width: safeWidth, height: style.trackHeight)
                        .offset(y: style.trackYOffset)

                    ForEach(timeline.segments) { segment in
                        Capsule(style: .continuous)
                            .fill(LineVisuals.segmentGradient(isActive: isActive))
                            .frame(
                                width: max(4, safeWidth * CGFloat(segment.endFraction - segment.startFraction)),
                                height: style.segmentHeight
                            )
                            .offset(x: safeWidth * CGFloat(segment.startFraction), y: style.segmentYOffset)
                            .shadow(
                                color: .white.opacity(isActive ? style.segmentShadowOpacity : 0.03),
                                radius: isActive ? style.segmentShadowRadius : 4,
                                x: 0,
                                y: 0
                            )
                    }

                    if showsFractureMarks {
                        ForEach(Array(timeline.breakFractions.enumerated()), id: \.offset) { item in
                            LineFractureMark(
                                size: style.fractureSize,
                                lineWidth: style.fractureLineWidth,
                                backgroundOpacity: 0.8,
                                lineOpacity: 0.68
                            )
                            .offset(
                                x: safeWidth * CGFloat(item.element) - style.fractureSize.width / 2,
                                y: style.fractureYOffset
                            )
                        }
                    }

                    Rectangle()
                        .fill(Color.white.opacity(markerOpacity))
                        .frame(width: 1, height: style.markerHeight)
                        .offset(x: currentX, y: style.markerYOffset)

                    if showsCurrentDot, let lastSegment = timeline.segments.last {
                        Circle()
                            .fill(Color.white.opacity(0.95))
                            .frame(width: 8, height: 8)
                            .shadow(color: .white.opacity(0.16), radius: 6, x: 0, y: 0)
                            .offset(
                                x: safeWidth * CGFloat(lastSegment.endFraction) - 4,
                                y: style.segmentYOffset
                            )
                    }

                    if let markerLabel {
                        Text(markerLabel)
                            .font(.system(size: 10, weight: .semibold, design: .serif))
                            .foregroundStyle(.white.opacity(0.9))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color.white.opacity(0.08))
                            )
                            .overlay(
                                Capsule(style: .continuous)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                            .offset(x: bubbleX - labelHalfWidth, y: -8)
                    }
                }
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(Color.white.opacity(trackStrokeOpacity), lineWidth: 1)
                        .frame(width: safeWidth, height: style.trackHeight)
                        .offset(y: style.trackYOffset)
                )
            }
            .frame(height: style.trackFrameHeight)

            if let labels {
                HStack {
                    Text(labels.leading)
                    Spacer()
                    Text(labels.middle)
                    Spacer()
                    Text(labels.trailing)
                }
                .font(.system(size: style.labelFontSize, weight: .medium, design: .serif))
                .foregroundStyle(MonochromeTheme.tertiaryText)
            }
        }
    }
}
