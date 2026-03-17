import SwiftData
import SwiftUI

@main
struct GrayscaleTimerApp: App {
    @Environment(\.scenePhase) private var scenePhase

    private let persistenceController: PersistenceController
    @StateObject private var trackingManager: GrayscaleTrackingManager

    init() {
        let persistenceController = PersistenceController.shared
        self.persistenceController = persistenceController
        _trackingManager = StateObject(
            wrappedValue: GrayscaleTrackingManager(modelContext: persistenceController.container.mainContext)
        )
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(trackingManager)
                .background(MonochromeTheme.background.ignoresSafeArea())
        }
        .modelContainer(persistenceController.container)
        .onChange(of: scenePhase, initial: true) { _, newPhase in
            trackingManager.handleScenePhaseChange(newPhase)
        }
    }
}
