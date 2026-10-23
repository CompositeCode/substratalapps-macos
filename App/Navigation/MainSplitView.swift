import SwiftUI
import SubstratalKit

/// `NavigationSplitView`: sidebar (Personal · Administration · Developer) and
/// the selected screen (PLATFORM-SPEC §3). Screens that need a middle list
/// column add it themselves.
struct MainSplitView: View {
    @Environment(AppModel.self) private var model
    @Environment(WindowNavigation.self) private var navigation
    @Environment(\.openURL) private var openURL

    var body: some View {
        @Bindable var navigation = navigation
        NavigationSplitView {
            SidebarView(selection: $navigation.sidebarSelection)
                .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 320)
        } detail: {
            ScreenHost(route: navigation.route)
                .id(navigation.route)
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    navigation.go("NTF-01")
                } label: {
                    Label("Inbox", systemImage: "tray")
                }
                .help("Inbox")
                .disabled(!model.capabilities.isVisible("flag:notifications"))

                Button {
                    openURL(model.help.screen(navigation.route.screenID))
                } label: {
                    Label("Help for This Screen", systemImage: "questionmark.circle")
                }
                .help("Help for this screen")

                AccountMenu()
            }
        }
        .task { await model.refreshCapabilities() }
    }
}

private struct AccountMenu: View {
    @Environment(AppModel.self) private var model
    @Environment(WindowNavigation.self) private var navigation

    var body: some View {
        Menu {
            Button("Account") { navigation.go("ACC-01") }
            Button("Security") { navigation.go("ACC-04") }
            Divider()
            Text("API: \(model.environment.displayName)")
            Divider()
            Button("Sign Out") { Task { await model.signOut() } }
        } label: {
            Label("Account", systemImage: "person.crop.circle")
        }
        .help("Account")
    }
}
