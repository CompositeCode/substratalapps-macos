import Foundation

/// Links into the Hub Help Center (the `help/` site in this repo, published to
/// GitHub Pages). Every screen has a page at `screens/<id>/`, generated from the
/// same `screens.json` the app navigates with, so a Help button can never point
/// at a page that doesn't exist.
public struct HelpLinks: Sendable {
    public static let defaultBase = URL(string: "https://compositecode.github.io/substratalapps-macos/")!

    public let base: URL

    /// `base` comes from Info.plist `SubstratalHelpBaseURL` so a staging build can
    /// point at a preview of the site.
    public init(base: URL = HelpLinks.defaultBase) {
        self.base = base
    }

    public init(bundle: Bundle) {
        let configured = (bundle.object(forInfoDictionaryKey: "SubstratalHelpBaseURL") as? String).flatMap(URL.init(string:))
        self.init(base: configured ?? Self.defaultBase)
    }

    public var home: URL { base }
    public var gettingStarted: URL { page("getting-started/") }
    public var tutorials: URL { page("tutorials/") }
    public var faq: URL { page("faq/") }
    public var shortcuts: URL { page("reference/keyboard-shortcuts/") }
    public var apiReference: URL { page("api/") }
    /// Swagger UI over the vendored openapi.yaml.
    public var apiExplorer: URL { page("api/reference/") }
    public var releaseNotes: URL { page("release-notes/") }

    public func screen(_ id: String) -> URL { page("screens/\(id.lowercased())/") }

    /// The API's own specification site (system of record for the contract).
    public static let apiSpecification = URL(string: "https://compositecode.github.io/substratalapps.com/")!

    private func page(_ path: String) -> URL {
        URL(string: path, relativeTo: base)!.absoluteURL
    }
}
