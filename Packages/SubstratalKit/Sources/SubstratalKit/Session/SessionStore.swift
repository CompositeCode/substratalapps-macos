import Foundation

/// The platform session: a 15-minute access token in memory and the refresh
/// token in the Keychain. An actor so token refresh is **single-flight**: any
/// number of concurrent requests that find the access token stale wait on one
/// refresh, and a rotated refresh token is never used twice (the API treats
/// reuse as theft and revokes the session).
public actor SessionStore {
    public struct Tokens: Sendable, Equatable {
        public var accessToken: String
        public var accessExpiresAt: Date
        public var refreshToken: String
        public var sessionID: String
        public var userID: String

        public init(accessToken: String, accessExpiresAt: Date, refreshToken: String, sessionID: String, userID: String) {
            self.accessToken = accessToken
            self.accessExpiresAt = accessExpiresAt
            self.refreshToken = refreshToken
            self.sessionID = sessionID
            self.userID = userID
        }
    }

    /// Exchanges a refresh token for new tokens (`POST /auth/token/refresh`).
    /// Throws `SessionError.expired` when the API rejects the token (401/403);
    /// any other error is treated as transient.
    public typealias Refresher = @Sendable (_ refreshToken: String) async throws -> Tokens

    public enum SessionError: Error, Equatable {
        case signedOut
        /// The refresh token was rejected; the person has to sign in again.
        case expired
    }

    private let keychain: any SecureStore
    private let accountKey: String
    private var tokens: Tokens?
    private var refreshTask: Task<Tokens, Error>?
    private var refresher: Refresher?
    private let clock: @Sendable () -> Date

    /// Refresh this long before the access token actually expires.
    private let skew: TimeInterval = 60

    public init(keychain: any SecureStore = KeychainStore(), accountKey: String = "refresh_token", clock: @escaping @Sendable () -> Date = Date.init) {
        self.keychain = keychain
        self.accountKey = accountKey
        self.clock = clock
    }

    public func setRefresher(_ refresher: @escaping Refresher) {
        self.refresher = refresher
    }

    /// Whether a stored refresh token exists, so launch can try to resume.
    public var hasStoredSession: Bool {
        tokens != nil || ((try? keychain.read(accountKey)) ?? nil) != nil
    }

    public var currentUserID: String? { tokens?.userID }

    public func signedIn(_ new: Tokens) throws {
        tokens = new
        try keychain.write(new.refreshToken, for: accountKey)
    }

    public func signOut() {
        tokens = nil
        refreshTask?.cancel()
        refreshTask = nil
        try? keychain.delete(accountKey)
    }

    /// A valid access token, refreshing first if needed. Throws `.signedOut` when
    /// there's no session at all.
    public func accessToken() async throws -> String {
        if let tokens, tokens.accessExpiresAt.timeIntervalSince(clock()) > skew {
            return tokens.accessToken
        }
        return try await refresh().accessToken
    }

    /// Resume from the Keychain at launch.
    public func resume() async throws -> Tokens {
        try await refresh()
    }

    private func refresh() async throws -> Tokens {
        if let refreshTask { return try await refreshTask.value }
        guard let refresher else { throw SessionError.signedOut }
        guard let refreshToken = tokens?.refreshToken ?? ((try? keychain.read(accountKey)) ?? nil) else {
            throw SessionError.signedOut
        }
        let task = Task { try await refresher(refreshToken) }
        refreshTask = task
        defer { refreshTask = nil }
        do {
            let new = try await task.value
            try signedIn(new)
            return new
        } catch SessionError.expired {
            // Only a rejected refresh token ends the session. A network failure
            // keeps it, so the next request can try again.
            signOut()
            throw SessionError.expired
        }
    }
}
