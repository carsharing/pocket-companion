import PetCore
import SwiftUI

@main
struct PocketCompanionApp: App {
    @StateObject private var model = CompanionModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(model)
                .task {
                    if model.notificationsEnabled {
                        _ = await ReminderScheduler.requestPermission()
                    }
                    ReminderScheduler.reschedule(for: model.state)
                }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active: model.refresh()
            case .background: ReminderScheduler.reschedule(for: model.state)
            default: break
            }
        }
    }
}
