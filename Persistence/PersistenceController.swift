import Foundation
import SwiftData

@MainActor
final class PersistenceController {
    static let shared = PersistenceController()

    let container: ModelContainer

    init(inMemory: Bool = false) {
        let schema = Schema([
            RunRecord.self,
            DaySummary.self,
            UnverifiedInterval.self
        ])

        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory
        )

        do {
            container = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            assertionFailure("Failed to initialize SwiftData container: \(error)")

            do {
                let fallbackConfiguration = ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: true
                )
                container = try ModelContainer(for: schema, configurations: [fallbackConfiguration])
            } catch {
                fatalError("Failed to initialize SwiftData container and in-memory fallback: \(error)")
            }
        }
    }
}
