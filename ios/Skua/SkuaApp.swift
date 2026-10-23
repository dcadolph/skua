import SwiftUI

// SkuaApp is the entry point. It also owns the background alert check.
@main
struct SkuaApp: App {
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
        .backgroundTask(.appRefresh(Notifier.refreshTaskID)) {
            await Notifier.backgroundCheck()
        }
        .onChange(of: scenePhase) { phase in
            if phase == .background {
                Notifier.scheduleRefresh()
            }
        }
    }
}
