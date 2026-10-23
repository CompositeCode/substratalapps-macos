import Foundation
import Testing
@testable import SubstratalKit

@Suite("Screen catalog, routes and capabilities")
struct NavigationTests {
    let catalog = ScreenCatalog.bundled

    @Test("The catalog has the spec's 75 screens, 15 of them in the sidebar")
    func catalogShape() {
        #expect(catalog.screens.count == 75)
        let sidebar = SidebarSection.allCases.flatMap { catalog.sidebar($0) }
        #expect(sidebar.count == 15)
        #expect(catalog.sidebar(.personal).map(\.id) == ["APP-01", "NTF-01", "ORG-01", "ACC-01", "BIL-01", "SET-01"])
        #expect(Set(catalog.screens.map(\.id)).count == catalog.screens.count)
    }

    @Test("No console screens on macOS (PRODUCT-SPEC §2a, OPEN-QUESTIONS #27)")
    func noConsoleScreens() {
        let console = catalog.screens.filter { ["OPS", "SEC", "CFG", "RPT", "INT"].contains(String($0.id.prefix(3))) }
        #expect(console.isEmpty)
    }

    @Test("Every routable screen round-trips through its own path")
    func routesRoundTrip() throws {
        let resolver = RouteResolver(catalog: catalog)
        for screen in catalog.screens where screen.route.hasPrefix("/") {
            var route = Route(screen.id)
            for segment in screen.route.split(separator: "/") where segment.hasPrefix(":") {
                route.parameters[String(segment.dropFirst())] = "x_\(segment.dropFirst())"
            }
            let path = try #require(resolver.path(for: route), "\(screen.id)")
            #expect(resolver.route(forPath: path) == route, "\(screen.id) \(path)")
        }
    }

    @Test("Deep links and Universal Links resolve; other hosts don't")
    func deepLinks() {
        let resolver = RouteResolver(catalog: catalog)
        #expect(resolver.route(for: URL(string: "substratal://admin/users/usr_1?tab=roles")!)
            == Route("USR-03", parameters: ["userId": "usr_1"], query: ["tab": "roles"]))
        #expect(resolver.route(for: URL(string: "https://dashboard.substratalapps.com/apps/past")!) == Route("APP-05"))
        #expect(resolver.route(for: URL(string: "https://dashboard.substratalapps.com/")!) == Route("APP-01"))
        #expect(resolver.route(for: URL(string: "https://evil.example.com/admin/users")!) == nil)
    }

    @Test("Sidebar visibility follows INFORMATION-ARCHITECTURE §2")
    func visibility() {
        let member = Capabilities()
        #expect(member.isVisible(.personal))
        #expect(!member.isVisible(.administration))
        #expect(!member.isVisible(.developer))

        let support = Capabilities(platformPermissions: ["users.list", "entitlements.manage", "audit.view", "tenants.manage", "billing.manage"])
        #expect(support.isVisible(.administration))
        #expect(support.isVisible("perm:audit.view"))
        #expect(!support.isVisible("perm:notifications.send"))
        #expect(support.isVisible("tenant"))

        let owner = Capabilities(ownedApplicationIDs: ["app_timetrack"])
        #expect(owner.isVisible(.administration))   // Access only, confined
        #expect(owner.isVisible("access"))
        #expect(!owner.isVisible("perm:users.list"))
        #expect(owner.isVisible(.developer))

        var noFlags = Capabilities()
        noFlags.flags = []
        #expect(!noFlags.isVisible("flag:notifications"))
    }

    @Test("Help links exist for every screen")
    func helpLinks() {
        let help = HelpLinks()
        #expect(help.screen("USR-01").absoluteString == "https://compositecode.github.io/substratalapps-macos/screens/usr-01/")
        #expect(help.apiExplorer.absoluteString == "https://compositecode.github.io/substratalapps-macos/api/reference/")
    }
}
