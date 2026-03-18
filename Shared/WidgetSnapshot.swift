import Foundation

enum WidgetLineState: String, Codable, Equatable {
    case intact
    case restored
    case breakOpen

    var title: String {
        switch self {
        case .intact:
            return "Line Intact"
        case .restored:
            return "Line Restored"
        case .breakOpen:
            return "Break Open"
        }
    }
}

struct WidgetSnapshot: Codable, Equatable {
    var isActive: Bool
    var activeRunStartTime: Date?
    var lineState: WidgetLineState
    var isDamaged: Bool
    var qualifyingProgress: Double
    var currentStreak: Int
    var lastUpdated: Date

    static let inactive = WidgetSnapshot(
        isActive: false,
        activeRunStartTime: nil,
        lineState: .breakOpen,
        isDamaged: true,
        qualifyingProgress: 0,
        currentStreak: 0,
        lastUpdated: .now
    )

    func isMeaningfullyEquivalent(to other: WidgetSnapshot) -> Bool {
        isActive == other.isActive &&
        activeRunStartTime == other.activeRunStartTime &&
        lineState == other.lineState &&
        isDamaged == other.isDamaged &&
        abs(qualifyingProgress - other.qualifyingProgress) < 0.01 &&
        currentStreak == other.currentStreak
    }
}

enum WidgetSnapshotStore {
    private static let fileName = "widget-snapshot.json"

    static func load() -> WidgetSnapshot {
        guard
            let fileURL = sharedContainerFileURL(),
            let data = try? Data(contentsOf: fileURL),
            let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
        else {
            return .inactive
        }

        return snapshot
    }

    static func save(_ snapshot: WidgetSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        guard let fileURL = sharedContainerFileURL() else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    private static func sharedContainerFileURL() -> URL? {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: AppConfig.appGroupIdentifier
        ) else {
            return nil
        }

        return containerURL.appendingPathComponent(fileName, isDirectory: false)
    }
}
