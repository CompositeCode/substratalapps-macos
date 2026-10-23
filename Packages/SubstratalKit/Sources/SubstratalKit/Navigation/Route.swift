import Foundation

/// Where a window is: a screen plus the path parameters and query its route
/// carries. Routes are the spec's (SCREEN-SPECS "Route" column), shared with
/// the web Hub, Universal Links and `substratal://` deep links.
public struct Route: Codable, Hashable, Sendable {
    public var screenID: String
    public var parameters: [String: String]
    public var query: [String: String]

    public init(_ screenID: String, parameters: [String: String] = [:], query: [String: String] = [:]) {
        self.screenID = screenID
        self.parameters = parameters
        self.query = query
    }

    public static let home = Route("APP-01")
    public static let signIn = Route("AUTH-01")
}

/// Turns URLs into routes and back, using the catalog's route patterns
/// (`/admin/users/:userId`).
public struct RouteResolver: Sendable {
    /// Hosts whose paths are Hub routes (Universal Links).
    public static let webHosts: Set<String> = ["dashboard.substratalapps.com"]
    public static let scheme = "substratal"

    private struct Pattern: Sendable {
        let screenID: String
        let segments: [String]
    }

    private let patterns: [Pattern]
    private let catalog: ScreenCatalog

    public init(catalog: ScreenCatalog) {
        self.catalog = catalog
        // Specific before generic: more literal segments first, then longer.
        patterns = catalog.screens
            .compactMap { screen -> Pattern? in
                let path = Self.primaryPath(of: screen.route)
                guard path.hasPrefix("/") else { return nil }
                return Pattern(screenID: screen.id, segments: Self.segments(path))
            }
            .sorted { lhs, rhs in
                let l = lhs.segments.filter { !$0.hasPrefix(":") }.count
                let r = rhs.segments.filter { !$0.hasPrefix(":") }.count
                return l != r ? l > r : lhs.segments.count > rhs.segments.count
            }
    }

    /// `substratal:///admin/users/usr_1?tab=roles`, `substratal://admin/users/usr_1`,
    /// or `https://dashboard.substratalapps.com/admin/users/usr_1`.
    public func route(for url: URL) -> Route? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        var path: String
        switch components.scheme?.lowercased() {
        case Self.scheme:
            // substratal://admin/users → host "admin", path "/users".
            path = (components.host.map { "/" + $0 } ?? "") + components.path
        case "https":
            guard let host = components.host, Self.webHosts.contains(host) else { return nil }
            path = components.path
        default:
            return nil
        }
        if path.isEmpty { path = "/" }
        let query = Dictionary(
            (components.queryItems ?? []).compactMap { item in item.value.map { (item.name, $0) } },
            uniquingKeysWith: { _, last in last }
        )
        return route(forPath: path, query: query)
    }

    public func route(forPath path: String, query: [String: String] = [:]) -> Route? {
        let parts = Self.segments(path)
        for pattern in patterns where pattern.segments.count == parts.count {
            var params: [String: String] = [:]
            var matched = true
            for (want, got) in zip(pattern.segments, parts) {
                if want.hasPrefix(":") {
                    params[String(want.dropFirst())] = got
                } else if want != got {
                    matched = false
                    break
                }
            }
            if matched { return Route(pattern.screenID, parameters: params, query: query) }
        }
        return nil
    }

    /// The canonical path for a route, with parameters filled in.
    public func path(for route: Route) -> String? {
        guard let screen = catalog[route.screenID] else { return nil }
        let pattern = Self.primaryPath(of: screen.route)
        guard pattern.hasPrefix("/") else { return nil }
        var segments: [String] = []
        for segment in Self.segments(pattern) {
            if segment.hasPrefix(":") {
                guard let value = route.parameters[String(segment.dropFirst())] else { return nil }
                segments.append(value)
            } else {
                segments.append(segment)
            }
        }
        return "/" + segments.joined(separator: "/")
    }

    /// Some spec routes carry notes or alternatives (`/billing (… )`, `a · b`);
    /// the first path-shaped token is the canonical one.
    static func primaryPath(of route: String) -> String {
        let token = route.split(whereSeparator: { $0 == " " || $0 == "·" || $0 == "," }).first.map(String.init) ?? route
        return token.split(separator: "?").first.map(String.init) ?? token
    }

    static func segments(_ path: String) -> [String] {
        path.split(separator: "/").map(String.init)
    }
}
