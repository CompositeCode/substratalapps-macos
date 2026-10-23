import Foundation
import OpenAPIRuntime
import OpenAPIURLSession
import SubstratalAPI

/// Builds the generated client with the Hub's middleware stack. Screens never
/// call HTTP directly; domain services take a `Client` from here.
public enum APIClientFactory {
    public static func make(
        environment: APIEnvironment,
        versionMonitor: APIVersionMonitor,
        token: @escaping AuthMiddleware.TokenProvider,
        appVersion: String,
        session: URLSession = .hub
    ) -> Client {
        Client(
            serverURL: environment.baseURL,
            configuration: Configuration(dateTranscoder: .iso8601WithFractionalSeconds),
            transport: URLSessionTransport(configuration: .init(session: session)),
            middlewares: [
                VersionMiddleware(monitor: versionMonitor),
                UserAgentMiddleware(appVersion: appVersion),
                IdempotencyMiddleware(),
                AuthMiddleware(token: token),
            ]
        )
    }
}

public extension URLSession {
    /// One shared session: connection reuse to API Gateway, no `URLCache` (the
    /// Hub caches explicitly), and it waits out brief network changes.
    static let hub: URLSession = {
        let config = URLSessionConfiguration.default
        config.urlCache = nil
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.waitsForConnectivity = true
        config.timeoutIntervalForRequest = 30
        config.httpAdditionalHeaders = ["Accept": "application/json"]
        return URLSession(configuration: config)
    }()
}
