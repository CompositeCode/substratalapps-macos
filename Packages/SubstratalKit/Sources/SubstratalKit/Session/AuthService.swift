import Foundation
import OpenAPIRuntime
import SubstratalAPI

/// Sign-in, MFA, refresh and sign-out (AUTH-01/02) over the generated client.
public struct AuthService: Sendable {
    public enum SignInResult: Sendable, Equatable {
        case signedIn(userID: String)
        /// Continue on AUTH-02 with this token (valid `expiresIn` seconds).
        case mfaRequired(mfaToken: String, methods: [String], expiresIn: Int)
    }

    let client: Client
    let session: SessionStore
    let clock: @Sendable () -> Date

    public init(client: Client, session: SessionStore, clock: @escaping @Sendable () -> Date = { Date() }) {
        self.client = client
        self.session = session
        self.clock = clock
    }


    public func signIn(email: String, password: String, testMode: Bool = false) async throws -> SignInResult {
        let output = try await client.auth_login(
            headers: .init(substratalVersion: APIVersion.current),
            body: .json(.init(email: email, password: password, testMode: testMode ? true : nil))
        )
        switch output {
        case .ok(let ok):
            switch try ok.body.json {
            case .AuthSession(let auth):
                try await session.signedIn(tokens(from: auth))
                return .signedIn(userID: auth.userId)
            case .MfaChallenge(let challenge):
                return .mfaRequired(
                    mfaToken: challenge.mfaToken,
                    methods: challenge.methods.map(\.rawValue),
                    expiresIn: challenge.expiresIn
                )
            }
        case .badRequest(let r): throw APIProblem(try r.body.json, status: 400)
        case .unauthorized(let r): throw APIProblem(try r.body.json, status: 401)
        case .forbidden(let r): throw APIProblem(try r.body.json, status: 403)
        case .tooManyRequests(let r): throw APIProblem(try r.body.json, status: 429)
        case .undocumented(let status, _): throw APIProblem.undocumented(status)
        }
    }

    /// AUTH-02: a TOTP code or a recovery code.
    public func verifyMFA(mfaToken: String, code: String? = nil, recoveryCode: String? = nil) async throws -> String {
        let output = try await client.auth_verifyMfa(
            headers: .init(substratalVersion: APIVersion.current),
            body: .json(.init(mfaToken: mfaToken, code: code, recoveryCode: recoveryCode))
        )
        guard case .ok(let ok) = output else { throw APIProblem.from(output) }
        let auth = try ok.body.json
        try await session.signedIn(tokens(from: auth))
        return auth.userId
    }

    /// The `SessionStore.Refresher`: 401/403 mean the refresh token is gone.
    public func refresh(_ refreshToken: String) async throws -> SessionStore.Tokens {
        let output = try await client.auth_refreshToken(
            headers: .init(substratalVersion: APIVersion.current),
            body: .json(.init(refreshToken: refreshToken))
        )
        switch output {
        case .ok(let ok): return tokens(from: try ok.body.json)
        case .unauthorized, .forbidden: throw SessionStore.SessionError.expired
        default: throw APIProblem.from(output)
        }
    }

    /// Ends this session on the server (best effort), then locally.
    public func signOut(allSessions: Bool = false) async {
        _ = try? await client.auth_logout(
            headers: .init(substratalVersion: APIVersion.current),
            body: .json(.init(allSessions: allSessions ? true : nil))
        )
        await session.signOut()
    }

    private func tokens(from auth: Components.Schemas.AuthSession) -> SessionStore.Tokens {
        SessionStore.Tokens(
            accessToken: auth.accessToken,
            accessExpiresAt: clock().addingTimeInterval(TimeInterval(auth.expiresIn)),
            refreshToken: auth.refreshToken,
            sessionID: auth.sessionId,
            userID: auth.userId
        )
    }
}
