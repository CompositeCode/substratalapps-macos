import SwiftUI
import SubstratalKit

@main
struct SubstratalHubApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        // Main window: sidebar · content · detail. Multiple windows (⌘N), each
        // with its own navigation and state restoration (PLATFORM-SPEC §2).
        WindowGroup("Substratal Hub", id: "main") {
            RootView()
                .environment(model)
                .substratalTheme(model.theme)
                .frame(minWidth: 900, minHeight: 600)
                .task { await model.launch() }
        }
        .defaultSize(width: 1280, height: 800)
        .commands { HubCommands(model: model) }

        // Any user / app / role in its own window ("Open in New Window").
        WindowGroup("Substratal Hub", id: "route", for: Route.self) { $route in
            RootView(initialRoute: route)
                .environment(model)
                .substratalTheme(model.theme)
                .frame(minWidth: 900, minHeight: 600)
        }

        Settings {
            SettingsView()
                .environment(model)
                .substratalTheme(model.theme)
        }
    }
}
