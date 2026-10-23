import Foundation
import SubstratalAPI

/// The Platform API version this build is written against.
///
/// The version is a request header, not part of the URL: every endpoint lives at
/// the host root (`https://api.substratalapps.com/users/me`, never `/v1/users/me`)
/// and every request carries `Substratal-Version: 1`. It is a compile-time
/// constant on purpose: moving to a new version is a code change shipped as an
/// app update, never remote config (CLIENT-ARCHITECTURE §4.1).
public enum APIVersion {
    /// Sent on every request by `VersionMiddleware`.
    public static let current: Components.Parameters.ApiVersion = ._1
    public static let headerName = "Substratal-Version"
    public static var headerValue: String { current.rawValue }
}

/// Where the Hub sends API traffic.
public enum APIEnvironment: Codable, Hashable, Sendable {
    /// `https://api.substratalapps.com` — production (the API repo's `main`).
    case production
    /// The API repo's local devserver (`make run` → `http://localhost:8080`).
    case local(URL)
    /// Any other deployment (a future staging account).
    case custom(URL)

    public static let localDefault = APIEnvironment.local(URL(string: "http://localhost:8080")!)

    /// Host root. No version segment.
    public var baseURL: URL {
        switch self {
        case .production: URL(string: "https://api.substratalapps.com")!
        case .local(let url), .custom(let url): url
        }
    }

    public var displayName: String {
        switch self {
        case .production: "Production"
        case .local: "Local devserver"
        case .custom(let url): url.host() ?? url.absoluteString
        }
    }
}
