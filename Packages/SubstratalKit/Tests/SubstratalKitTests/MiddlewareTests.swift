import Foundation
import HTTPTypes
import OpenAPIRuntime
import Testing
@testable import SubstratalKit

@Suite("Request middleware")
struct MiddlewareTests {
    /// Records what reached the transport and returns a canned response.
    final class Recorder: @unchecked Sendable {
        var request: HTTPRequest?
        let response: HTTPResponse
        let body: String?

        init(status: HTTPResponse.Status = .ok, headers: HTTPFields = [:], body: String? = nil) {
            response = HTTPResponse(status: status, headerFields: headers)
            self.body = body
        }

        func next(_ request: HTTPRequest, _ body: HTTPBody?, _ url: URL) async throws -> (HTTPResponse, HTTPBody?) {
            self.request = request
            return (response, self.body.map { HTTPBody($0) })
        }
    }

    let url = URL(string: "https://api.substratalapps.com")!

    @Test("Every request carries Substratal-Version: 1, overriding any stray value")
    func stampsVersion() async throws {
        let recorder = Recorder()
        var request = HTTPRequest(method: .get, scheme: "https", authority: "api.substratalapps.com", path: "/users/me")
        request.headerFields[HTTPField.Name("Substratal-Version")!] = "99"
        _ = try await VersionMiddleware(monitor: APIVersionMonitor())
            .intercept(request, body: nil, baseURL: url, operationID: "users.get", next: recorder.next)
        #expect(recorder.request?.headerFields[HTTPField.Name("Substratal-Version")!] == "1")
    }

    @Test("Paths have no version prefix")
    func hostRootBaseURL() {
        #expect(APIEnvironment.production.baseURL.absoluteString == "https://api.substratalapps.com")
        #expect(!APIEnvironment.production.baseURL.path().contains("v1"))
    }

    @Test("Deprecation and Sunset mark the build deprecated")
    func deprecation() async throws {
        let monitor = APIVersionMonitor()
        let recorder = Recorder(headers: [
            HTTPField.Name("Deprecation")!: "@1798761600",
            HTTPField.Name("Sunset")!: "Mon, 26 Apr 2027 00:00:00 GMT",
        ])
        let request = HTTPRequest(method: .get, scheme: "https", authority: "api.substratalapps.com", path: "/users/me")
        _ = try await VersionMiddleware(monitor: monitor)
            .intercept(request, body: nil, baseURL: url, operationID: "users.get", next: recorder.next)
        guard case .deprecated(let sunset) = monitor.status else {
            Issue.record("expected deprecated, got \(monitor.status)")
            return
        }
        #expect(sunset == Date(timeIntervalSince1970: 1_808_697_600))
    }

    @Test("400 unsupported_api_version stops the build, and the body still reaches the decoder")
    func unsupported() async throws {
        let monitor = APIVersionMonitor()
        let json = #"{"error":{"code":"unsupported_api_version","message":"no","details":{"supported":["2"]}}}"#
        let recorder = Recorder(status: .badRequest, body: json)
        let request = HTTPRequest(method: .get, scheme: "https", authority: "api.substratalapps.com", path: "/users/me")
        let (_, body) = try await VersionMiddleware(monitor: monitor)
            .intercept(request, body: nil, baseURL: url, operationID: "users.get", next: recorder.next)
        #expect(monitor.status == .unsupported(supported: ["2"]))
        let passedOn = try await String(collecting: body!, upTo: 1024)
        #expect(passedOn == json)
    }

    @Test("api_version_required is a client bug, not an update prompt")
    func versionRequiredIsNotUnsupported() async throws {
        let monitor = APIVersionMonitor()
        let json = #"{"error":{"code":"api_version_required","message":"no","details":{"supported":["1"]}}}"#
        let request = HTTPRequest(method: .get, scheme: "https", authority: "api.substratalapps.com", path: "/users/me")
        _ = try await VersionMiddleware(monitor: monitor)
            .intercept(request, body: nil, baseURL: url, operationID: "users.get", next: Recorder(status: .badRequest, body: json).next)
        #expect(monitor.status == .current)
    }

    @Test("Bearer token on authenticated operations only")
    func bearer() async throws {
        let auth = AuthMiddleware { "tok_123" }
        let request = HTTPRequest(method: .post, scheme: "https", authority: "api.substratalapps.com", path: "/auth/token/refresh")

        let refresh = Recorder()
        _ = try await auth.intercept(request, body: nil, baseURL: url, operationID: "auth.refreshToken", next: refresh.next)
        #expect(refresh.request?.headerFields[.authorization] == nil)

        let users = Recorder()
        _ = try await auth.intercept(request, body: nil, baseURL: url, operationID: "users.list", next: users.next)
        #expect(users.request?.headerFields[.authorization] == "Bearer tok_123")
    }

    @Test("POSTs get an Idempotency-Key; an existing one is kept")
    func idempotency() async throws {
        let middleware = IdempotencyMiddleware()
        let post = Recorder()
        _ = try await middleware.intercept(
            HTTPRequest(method: .post, scheme: "https", authority: "a", path: "/users"),
            body: nil, baseURL: url, operationID: "users.create", next: post.next
        )
        #expect(post.request?.headerFields[HTTPField.Name("Idempotency-Key")!]?.isEmpty == false)

        var keyed = HTTPRequest(method: .post, scheme: "https", authority: "a", path: "/users")
        keyed.headerFields[HTTPField.Name("Idempotency-Key")!] = "fixed"
        let kept = Recorder()
        _ = try await middleware.intercept(keyed, body: nil, baseURL: url, operationID: "users.create", next: kept.next)
        #expect(kept.request?.headerFields[HTTPField.Name("Idempotency-Key")!] == "fixed")

        let get = Recorder()
        _ = try await middleware.intercept(
            HTTPRequest(method: .get, scheme: "https", authority: "a", path: "/users"),
            body: nil, baseURL: url, operationID: "users.list", next: get.next
        )
        #expect(get.request?.headerFields[HTTPField.Name("Idempotency-Key")!] == nil)
    }
}
