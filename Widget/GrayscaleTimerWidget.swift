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

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(entry.snapshot.isActive ? "Current Run" : "Grayscale Off")
                .font(.system(size: 12, weight: .semibold, design: .serif))
                .foregroundStyle(MonochromeTheme.secondaryText)
                .textCase(.uppercase)
                .tracking(1.2)

            Group {
                if entry.snapshot.isActive, let startTime = entry.snapshot.activeRunStartTime {
                    Text(startTime, style: .timer)
                        .font(.system(size: 30, weight: .ultraLight, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                        .foregroundStyle(.white)
                } else {
                    Text("Off")
                        .font(.system(size: 30, weight: .ultraLight, design: .serif))
                        .foregroundStyle(.white)
                }
            }

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 4) {
                Text("Qualifying Streak")
                    .font(.system(size: 11, weight: .medium, design: .serif))
                    .foregroundStyle(MonochromeTheme.tertiaryText)
                    .textCase(.uppercase)
                    .tracking(1.2)

                Text("\(entry.snapshot.currentStreak)")
                    .font(.system(size: 22, weight: .light, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
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
        .description("Shows the current verified run or that grayscale is off, plus the current streak.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct GrayscaleTimerWidgetBundle: WidgetBundle {
    var body: some Widget {
        GrayscaleTimerWidget()
    }
}
