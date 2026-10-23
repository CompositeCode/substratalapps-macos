import SwiftUI
import SubstratalKit

/// Maps a route to its screen. Screens are added here as they're built; every
/// other screen shows its spec placeholder, so all 75 are reachable from day one.
struct ScreenHost: View {
    @Environment(AppModel.self) private var model
    let route: Route

    var body: some View {
        if let screen = model.catalog[route.screenID] {
            content(for: screen)
                .navigationTitle(screen.sidebar?.label ?? screen.title)
                .navigationSubtitle(screen.id)
        } else {
            ContentUnavailableView("Page not found", systemImage: "questionmark.folder", description: Text(route.screenID))
        }
    }

    @ViewBuilder
    private func content(for screen: Screen) -> some View {
        switch screen.id {
        case "USR-01": UsersView()
        case "SET-01": AppearanceSettings()
        default: ScreenPlaceholder(screen: screen)
        }
    }
}
