import SwiftUI
import SubstratalKit

/// Menus. Every shortcut appears in a menu (HIG discoverability, PLATFORM-SPEC §4).
struct HubCommands: Commands {
    let model: AppModel
    @FocusedValue(\.navigation) private var navigation
    @Environment(\.openURL) private var openURL

    var body: some Commands {
        SidebarCommands()

        CommandMenu("Go") {
            ForEach(SidebarSection.allCases, id: \.self) { section in
                Section(section.title) {
                    ForEach(model.catalog.sidebar(section)) { screen in
                        if let sidebar = screen.sidebar {
                            goButton(screen, sidebar)
                        }
                    }
                }
            }
        }

        CommandGroup(after: .toolbar) {
            Button("Refresh") {
                Task { await model.refreshCapabilities() }
            }
            .keyboardShortcut("r")
        }

        CommandGroup(replacing: .help) {
            Button("Substratal Hub Help") { openURL(model.help.home) }
                .keyboardShortcut("?")
            Button("Help for This Screen") {
                if let id = navigation?.route.screenID { openURL(model.help.screen(id)) }
            }
            .disabled(navigation == nil)
            Divider()
            Button("Getting Started") { openURL(model.help.gettingStarted) }
            Button("Tutorials") { openURL(model.help.tutorials) }
            Button("Keyboard Shortcuts") { openURL(model.help.shortcuts) }
            Button("Frequently Asked Questions") { openURL(model.help.faq) }
            Button("Release Notes") { openURL(model.help.releaseNotes) }
            Divider()
            Button("API Reference") { openURL(model.help.apiExplorer) }
            Button("API Specification") { openURL(HelpLinks.apiSpecification) }
        }
    }

    @ViewBuilder
    private func goButton(_ screen: Screen, _ sidebar: Screen.Sidebar) -> some View {
        let button = Button(sidebar.label) { navigation?.go(screen.id) }
            .disabled(navigation == nil || !model.capabilities.isVisible(sidebar.visibleWhen))
        if let shortcut = KeyCombo.shortcut(sidebar.shortcut) {
            button.keyboardShortcut(shortcut)
        } else {
            button
        }
    }
}
