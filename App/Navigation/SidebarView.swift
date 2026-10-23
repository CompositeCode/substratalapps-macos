import SwiftUI
import SubstratalKit

/// The full navigation tree, gated by Capabilities (INFORMATION-ARCHITECTURE §2):
/// hide what the person can never use.
struct SidebarView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @Binding var selection: String?

    var body: some View {
        List(selection: $selection) {
            ForEach(SidebarSection.allCases, id: \.self) { section in
                let items = visibleItems(in: section)
                if model.capabilities.isVisible(section), !items.isEmpty {
                    Section(section.title) {
                        ForEach(items) { screen in
                            if let sidebar = screen.sidebar {
                                Label(sidebar.label, systemImage: sidebar.symbol)
                                    .tag(screen.id)
                                    .contextMenu {
                                        Button("Open in New Window") {
                                            openWindow(id: "route", value: Route(screen.id))
                                        }
                                    }
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(palette.sidebar.opacity(0.92))
    }

    @Environment(\.openWindow) private var openWindow

    private func visibleItems(in section: SidebarSection) -> [Screen] {
        model.catalog.sidebar(section).filter { screen in
            screen.sidebar.map { model.capabilities.isVisible($0.visibleWhen) } ?? false
        }
    }
}
