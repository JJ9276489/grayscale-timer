import SwiftUI
import WidgetKit

struct GrayscaleTimerWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct GrayscaleTimerTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> GrayscaleTimerWidgetEntry {
        GrayscaleTimerWidgetEntry(
            date: .now,
            snapshot: WidgetSnapshot(
                isActive: true,
                activeRunStartTime: .now.addingTimeInterval(-7_200),
                lineState: .intact,
                isDamaged: false,
                qualifyingProgress: 0.82,
                currentStreak: 6,
                lastUpdated: .now
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (GrayscaleTimerWidgetEntry) -> Void) {
        let snapshot = WidgetSnapshotStore.load()
        completion(GrayscaleTimerWidgetEntry(date: .now, snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GrayscaleTimerWidgetEntry>) -> Void) {
        let snapshot = WidgetSnapshotStore.load()
        let now = Date()
        let refreshDate = now.addingTimeInterval(snapshot.isActive ? AppConfig.widgetRefreshInterval : 30 * 60)
        let timeline = Timeline(
            entries: [GrayscaleTimerWidgetEntry(date: now, snapshot: snapshot)],
            policy: .after(refreshDate)
        )
        completion(timeline)
    }
}

struct GrayscaleTimerWidgetEntryView: View {
    let entry: GrayscaleTimerTimelineProvider.Entry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        VStack(alignment: .leading, spacing: family == .systemSmall ? 12 : 14) {
            Text("Current Line")
                .font(.system(size: 12, weight: .semibold, design: .serif))
                .foregroundStyle(MonochromeTheme.secondaryText)
                .textCase(.uppercase)
                .tracking(1.2)

            WidgetLineGlyph(snapshot: entry.snapshot)

            Group {
                if entry.snapshot.isActive, let startTime = entry.snapshot.activeRunStartTime {
                    Text(startTime, style: .timer)
                        .font(.system(size: family == .systemSmall ? 28 : 34, weight: .ultraLight, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                        .foregroundStyle(.white)
                } else {
                    Text(entry.snapshot.lineState.title)
                        .font(.system(size: family == .systemSmall ? 26 : 30, weight: .light, design: .serif))
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)
                        .foregroundStyle(.white)
                }
            }

            Spacer(minLength: 0)

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Streak")
                        .font(.system(size: 11, weight: .medium, design: .serif))
                        .foregroundStyle(MonochromeTheme.tertiaryText)
                        .textCase(.uppercase)
                        .tracking(1.2)

                    Text("\(entry.snapshot.currentStreak)")
                        .font(.system(size: 22, weight: .light, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                }

                Spacer(minLength: 0)

                Text(entry.snapshot.lineState.title)
                    .font(.system(size: 11, weight: .medium, design: .serif))
                    .foregroundStyle(MonochromeTheme.tertiaryText)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(18)
        .containerBackground(for: .widget) {
            ZStack {
                MonochromeTheme.background
                Color.black.opacity(0.45)
            }
        }
    }
}

struct GrayscaleTimerWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: AppConfig.widgetKind, provider: GrayscaleTimerTimelineProvider()) { entry in
            GrayscaleTimerWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Grayscale Timer")
        .description("Shows the current line, live timer, and streak.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct GrayscaleTimerWidgetBundle: WidgetBundle {
    var body: some Widget {
        GrayscaleTimerWidget()
    }
}

private struct WidgetLineGlyph: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        VStack(spacing: 10) {
            GeometryReader { geometry in
                let safeWidth = geometry.size.width
                let trackHeight: CGFloat = 4

                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.08))
                        .frame(width: safeWidth, height: trackHeight)

                    if snapshot.isActive, !snapshot.isDamaged {
                        Capsule(style: .continuous)
                            .fill(LineVisuals.segmentGradient(isActive: true))
                            .frame(width: safeWidth, height: trackHeight)
                            .shadow(color: .white.opacity(0.12), radius: 6, x: 0, y: 0)

                        Circle()
                            .fill(Color.white.opacity(0.92))
                            .frame(width: 7, height: 7)
                            .shadow(color: .white.opacity(0.14), radius: 4, x: 0, y: 0)
                            .offset(x: safeWidth - 7, y: -1.5)
                    } else if snapshot.isActive {
                        Capsule(style: .continuous)
                            .fill(LineVisuals.segmentGradient(isActive: true))
                            .frame(width: safeWidth * 0.46, height: trackHeight)

                        Capsule(style: .continuous)
                            .fill(LineVisuals.segmentGradient(isActive: true))
                            .frame(width: safeWidth * 0.34, height: trackHeight)
                            .offset(x: safeWidth * 0.58)

                        Circle()
                            .fill(Color.white.opacity(0.9))
                            .frame(width: 7, height: 7)
                            .offset(x: safeWidth * 0.92 - 7, y: -1.5)
                    } else {
                        Capsule(style: .continuous)
                            .fill(Color.white.opacity(0.22))
                            .frame(width: safeWidth * 0.28, height: trackHeight)

                        Capsule(style: .continuous)
                            .fill(Color.white.opacity(0.18))
                            .frame(width: safeWidth * 0.22, height: trackHeight)
                            .offset(x: safeWidth * 0.68)
                    }
                }
            }
            .frame(height: 8)

            LineProgressRail(progress: snapshot.qualifyingProgress, isActive: snapshot.isActive)
                .frame(height: 2)
        }
    }
}
