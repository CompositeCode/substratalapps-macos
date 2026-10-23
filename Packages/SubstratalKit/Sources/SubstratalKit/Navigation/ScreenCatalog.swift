import Foundation

/// One screen from the UI spec (macOS/SCREENS.md), as imported into
/// `Resources/screens.json` by `scripts/import-screens.rb`. The same file feeds
/// the help site, so navigation and documentation can't drift apart.
public struct Screen: Codable, Hashable, Identifiable, Sendable {
    public struct Sidebar: Codable, Hashable, Sendable {
        public let section: SidebarSection
        public let label: String
        public let symbol: String
        /// `cmd+1`, `opt+cmd+2`, `ctrl+cmd+3` — see `KeyCombo`.
        public let shortcut: String?
        /// A `Capabilities` visibility rule (`always`, `flag:x`, `perm:x`, `access`, `developer`, `tenant`).
        public let visibleWhen: String
        /// Position in the sidebar (PLATFORM-SPEC §3 order), across all sections.
        public let order: Int

        enum CodingKeys: String, CodingKey {
            case section, label, symbol, shortcut, order
            case visibleWhen = "visible_when"
        }
    }

    public let id: String
    public let title: String
    public let domain: String
    public let route: String
    public let archetype: String
    public let phase: String
    public let audience: String?
    public let purpose: String
    public let sidebar: Sidebar?

    /// The domain code, e.g. `D6` from `D6 Users`, or `G` for the shell.
    public var domainCode: String { String(domain.prefix { $0 != " " }) }
    public var domainName: String { String(domain.drop { $0 != " " }.dropFirst()) }
}

public enum SidebarSection: String, Codable, CaseIterable, Sendable {
    case personal, administration, developer

    public var title: String {
        switch self {
        case .personal: "Personal"
        case .administration: "Administration"
        case .developer: "Developer"
        }
    }
}

public struct ScreenCatalog: Sendable {
    public let spec: String?
    public let screens: [Screen]
    private let byID: [String: Screen]

    public init(screens: [Screen], spec: String? = nil) {
        self.screens = screens
        self.spec = spec
        byID = Dictionary(uniqueKeysWithValues: screens.map { ($0.id, $0) })
    }

    /// The catalog bundled with SubstratalKit.
    public static let bundled: ScreenCatalog = {
        guard let url = Bundle.module.url(forResource: "screens", withExtension: "json") else {
            fatalError("screens.json missing from SubstratalKit resources")
        }
        do {
            return try load(from: Data(contentsOf: url))
        } catch {
            fatalError("screens.json is invalid: \(error)")
        }
    }()

    public static func load(from data: Data) throws -> ScreenCatalog {
        struct File: Decodable { let spec: String?; let screens: [Screen] }
        let file = try JSONDecoder().decode(File.self, from: data)
        return ScreenCatalog(screens: file.screens, spec: file.spec)
    }

    public subscript(id: String) -> Screen? { byID[id] }

    /// Sidebar destinations in spec order, grouped by section.
    public func sidebar(_ section: SidebarSection) -> [Screen] {
        screens
            .filter { $0.sidebar?.section == section }
            .sorted { ($0.sidebar?.order ?? 0) < ($1.sidebar?.order ?? 0) }
    }

    /// Screens grouped by domain, in spec order (for the help index and palette).
    public var domains: [(domain: String, screens: [Screen])] {
        var order: [String] = []
        var groups: [String: [Screen]] = [:]
        for screen in screens {
            if groups[screen.domain] == nil { order.append(screen.domain) }
            groups[screen.domain, default: []].append(screen)
        }
        return order.map { ($0, groups[$0]!) }
    }
}
