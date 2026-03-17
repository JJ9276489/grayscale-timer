import SwiftUI

struct HeatmapView: View {
    let days: [HeatmapDay]
    @Binding var selectedDate: Date?
    var cellSize: CGFloat = 16
    var spacing: CGFloat = 6
    var interactive = true

    private var calendar: Calendar { .autoupdatingCurrent }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: spacing) {
                ForEach(Array(weekColumns.enumerated()), id: \.offset) { _, week in
                    VStack(spacing: spacing) {
                        ForEach(Array(week.enumerated()), id: \.offset) { _, day in
                            if let day {
                                dayCell(for: day)
                            } else {
                                RoundedRectangle(cornerRadius: max(3, cellSize * 0.24), style: .continuous)
                                    .fill(Color.clear)
                                    .frame(width: cellSize, height: cellSize)
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var weekColumns: [[HeatmapDay?]] {
        guard let firstDate = days.first?.date, let lastDate = days.last?.date else {
            return []
        }

        let normalizedFirst = calendar.startOfDay(for: firstDate)
        let normalizedLast = calendar.startOfDay(for: lastDate)
        let firstWeekStart = calendar.dateInterval(of: .weekOfYear, for: normalizedFirst)?.start ?? normalizedFirst
        let dayMap = Dictionary(uniqueKeysWithValues: days.map { (calendar.startOfDay(for: $0.date), $0) })

        var columns: [[HeatmapDay?]] = []
        var currentWeekStart = firstWeekStart

        while currentWeekStart <= normalizedLast {
            let week = (0..<7).map { offset -> HeatmapDay? in
                guard let day = calendar.date(byAdding: .day, value: offset, to: currentWeekStart) else {
                    return nil
                }

                return dayMap[calendar.startOfDay(for: day)]
            }

            columns.append(week)

            guard let nextWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: currentWeekStart) else {
                break
            }

            currentWeekStart = nextWeek
        }

        return columns
    }

    @ViewBuilder
    private func dayCell(for day: HeatmapDay) -> some View {
        let isSelected = selectedDate.map { calendar.isDate($0, inSameDayAs: day.date) } ?? false
        let fillOpacity = 0.06 + (min(day.intensity, 1) * 0.88)
        let borderColor: Color = {
            if day.snapshot.perfect {
                return .white
            }

            if isSelected {
                return Color.white.opacity(0.5)
            }

            return .clear
        }()

        let cell = RoundedRectangle(cornerRadius: max(3, cellSize * 0.24), style: .continuous)
            .fill(Color.white.opacity(fillOpacity))
            .overlay(
                RoundedRectangle(cornerRadius: max(3, cellSize * 0.24), style: .continuous)
                    .stroke(borderColor, lineWidth: (day.snapshot.perfect || isSelected) ? 1.15 : 0)
            )
            .frame(width: cellSize, height: cellSize)

        if interactive {
            Button {
                selectedDate = day.date
            } label: {
                cell
            }
            .buttonStyle(.plain)
        } else {
            cell
        }
    }
}
