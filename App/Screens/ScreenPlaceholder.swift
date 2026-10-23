import SwiftUI
import SubstratalKit

/// Stands in for a screen that isn't built yet: what it is, who it's for, and
/// where its spec and help page are. Removed screen by screen as they land.
struct ScreenPlaceholder: View {
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @Environment(\.openURL) private var openURL
    let screen: Screen

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .firstTextBaseline) {
                    Text(screen.title).font(.title2.weight(.semibold))
                    Text(screen.id)
                        .font(.callout.monospaced())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(palette.accentSubtle, in: .capsule)
                        .textSelection(.enabled)
                }
                Text(screen.purpose)
                    .font(.body)
                    .foregroundStyle(palette.textSecondary)

                GroupBox {
                    Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                        row("Domain", screen.domain)
                        row("Route", screen.route, monospaced: true)
                        row("Layout", screen.archetype)
                        row("Phase", screen.phase)
                        if let audience = screen.audience { row("Who", audience) }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(4)
                }

                Label("This screen is specified but not built yet.", systemImage: "hammer")
                    .foregroundStyle(palette.textSecondary)

                HStack {
                    Button("Help for This Screen") { openURL(model.help.screen(screen.id)) }
                    Button("Screen Specification") { openURL(specURL) }
                }
            }
            .padding(20)
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(palette.background)
    }

    private var specURL: URL {
        URL(string: "https://compositecode.github.io/substratalapps-applications-specs/spec/macos/SCREENS.html")!
    }

    @ViewBuilder
    private func row(_ label: String, _ value: String, monospaced: Bool = false) -> some View {
        GridRow {
            Text(label).foregroundStyle(palette.textSecondary)
            Text(value).font(monospaced ? .body.monospaced() : .body).textSelection(.enabled)
        }
    }
}
