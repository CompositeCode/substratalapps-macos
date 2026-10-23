import Foundation

/// Links into the Substratal Hub help center, the one documentation reference
/// every Hub app shares. It's built from the specs repository
/// (`CompositeCode/substratalapps-applications-specs`, `help/` and
/// `site/help.mjs`) and published at `…/substratalapps-applications-specs/help/`.
/// Every screen has a page at `screens/<id>.html`, generated from the same
/// spec this app's screen catalog is imported from. CI checks that every link
/// here exists in a fresh build of that site (`scripts/help-check.rb`).
public struct HelpLinks: Sendable {
    public static let defaultBase = URL(string: "https://compositecode.github.io/substratalapps-applications-specs/help/")!

    public let base: URL

    /// `base` comes from Info.plist `SubstratalHelpBaseURL`, so a build can
    /// point at a preview of the site.
    public init(base: URL = HelpLinks.defaultBase) {
        self.base = base
    }

    public init(bundle: Bundle) {
        let configured = (bundle.object(forInfoDictionaryKey: "SubstratalHelpBaseURL") as? String).flatMap(URL.init(string:))
        self.init(base: configured ?? Self.defaultBase)
    }

    public var home: URL { page("index.html") }
    public var gettingStarted: URL { page("guides/getting-started.html") }
    /// Shortcuts, windows, the Keychain and Settings → Connection.
    public var macOSGuide: URL { page("guides/macos.html") }
    public var shortcuts: URL { page("guides/macos.html", fragment: "keyboard-shortcuts") }
    public var troubleshooting: URL { page("guides/troubleshooting.html") }
    public var faq: URL { page("faq.html") }
    public var whatsNew: URL { page("whats-new.html") }
    public var apiQuickstart: URL { page("developers/quickstart.html") }
    public var apiVersioning: URL { page("developers/api-versioning.html") }
    /// Swagger UI for the API version this build speaks.
    public var apiExplorer: URL { page("api/v\(APIVersion.headerValue)/index.html") }

    public func screen(_ id: String) -> URL { page("screens/\(id.lowercased()).html") }

    /// The API's own specification site (system of record for the contract).
    public static let apiSpecification = URL(string: "https://compositecode.github.io/substratalapps.com/")!

    private func page(_ path: String, fragment: String? = nil) -> URL {
        var components = URLComponents(url: URL(string: path, relativeTo: base)!.absoluteURL, resolvingAgainstBaseURL: true)!
        components.fragment = fragment
        return components.url!
    }
}
