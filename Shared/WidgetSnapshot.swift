import Foundation

struct WidgetSnapshot: Codable, Equatable {
    var isActive: Bool
    var activeRunStartTime: Date?
    var currentStreak: Int
    var lastUpdated: Date

    static let inactive = WidgetSnapshot(
        isActive: false,
        activeRunStartTime: nil,
        currentStreak: 0,
        lastUpdated: .now
    )
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
