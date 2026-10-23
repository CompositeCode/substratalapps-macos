import Foundation
import HTTPTypes
import OpenAPIRuntime

extension HTTPField.Name {
    static let substratalVersion = HTTPField.Name(APIVersion.headerName)!
    static let deprecation = HTTPField.Name("Deprecation")!
    static let sunset = HTTPField.Name("Sunset")!
    static let idempotencyKey = HTTPField.Name("Idempotency-Key")!
    static let requestID = HTTPField.Name("X-Request-Id")!
}

/// Stamps `Substratal-Version` on **every** request, including auth calls and the
/// exempt ones (harmless there), and reads the version signals off every response.
///
/// Generated operations also take the version as a typed input; this middleware
/// guarantees the header even for requests built by hand, and overrides any
/// stray value so one build only ever speaks one version.
public struct VersionMiddleware: ClientMiddleware {
    let monitor: APIVersionMonitor

    public init(monitor: APIVersionMonitor) { self.monitor = monitor }

    public func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String,
        next: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        var request = request
        request.headerFields[.substratalVersion] = APIVersion.headerValue
        let (response, responseBody) = try await next(request, body, baseURL)

        monitor.record(echo: response.headerFields[.substratalVersion])
        monitor.record(deprecation: response.headerFields[.deprecation], sunset: response.headerFields[.sunset])

        // 400 unsupported_api_version: peek at the (small) error body, then hand
        // an identical body on so the generated decoder still sees it.
        guard response.status == .badRequest, let responseBody else { return (response, responseBody) }
        let data = try await Data(collecting: responseBody, upTo: 64 * 1024)
        if let envelope = try? JSONDecoder().decode(ErrorEnvelope.self, from: data),
           envelope.error.code == "unsupported_api_version" {
            monitor.recordUnsupported(supported: envelope.error.details?.supported ?? [])
        }
        return (response, HTTPBody(data))
    }
}

/// Adds `Authorization: Bearer …` from the session, except on the operations the
/// spec marks `security: []` (sign-in, refresh, emailed-link flows). Skipping
/// refresh here is what keeps the single-flight refresh from waiting on itself.
public struct AuthMiddleware: ClientMiddleware {
    public typealias TokenProvider = @Sendable () async throws -> String?

    /// operationIds with `security: []` in openapi.yaml.
    static let unauthenticated: Set<String> = [
        "health.check", "auth.signup", "auth.login", "auth.verifyMfa", "auth.refreshToken",
        "auth.exchangeOAuthToken", "auth.verifyEmail", "auth.resendEmailVerification",
        "auth.forgotPassword", "auth.resetPassword", "auth.acceptInvitation", "auth.ssoCallback",
    ]

    let token: TokenProvider

    public init(token: @escaping TokenProvider) { self.token = token }

    public func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String,
        next: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        var request = request
        if !Self.unauthenticated.contains(operationID), let token = try await token() {
            request.headerFields[.authorization] = "Bearer \(token)"
        }
        return try await next(request, body, baseURL)
    }
}

/// Adds an `Idempotency-Key` to every `POST` that doesn't already carry one, so a
/// retried create (sleep/wake, flaky network) never runs twice.
public struct IdempotencyMiddleware: ClientMiddleware {
    public init() {}

    public func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String,
        next: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        var request = request
        if request.method == .post, request.headerFields[.idempotencyKey] == nil {
            request.headerFields[.idempotencyKey] = UUID().uuidString.lowercased()
        }
        return try await next(request, body, baseURL)
    }
}

/// A descriptive `User-Agent`, which the API shows as the session name (OPEN-QUESTIONS #7).
public struct UserAgentMiddleware: ClientMiddleware {
    let value: String

    public init(appVersion: String, osVersion: String = ProcessInfo.processInfo.operatingSystemVersionString) {
        value = "SubstratalHub/\(appVersion) (macOS \(osVersion))"
    }

    public func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String,
        next: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        var request = request
        request.headerFields[.userAgent] = value
        return try await next(request, body, baseURL)
    }
}

/// The API's error envelope: `{ "error": { "code", "message", "details" } }`.
struct ErrorEnvelope: Decodable {
    struct Body: Decodable {
        struct Details: Decodable { let supported: [String]? }
        let code: String
        let message: String?
        let details: Details?
    }
    let error: Body
}
