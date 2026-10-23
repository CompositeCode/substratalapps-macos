import Foundation
import Testing
@testable import SubstratalKit

@Suite("Session store")
struct SessionStoreTests {
    func makeStore(now: @escaping @Sendable () -> Date = Date.init) -> (SessionStore, InMemorySecureStore) {
        let storage = InMemorySecureStore()
        return (SessionStore(keychain: storage, clock: now), storage)
    }

    func tokens(_ n: Int, expiresIn: TimeInterval = 900) -> SessionStore.Tokens {
        .init(accessToken: "access_\(n)", accessExpiresAt: Date().addingTimeInterval(expiresIn), refreshToken: "refresh_\(n)", sessionID: "ses_1", userID: "usr_1")
    }

    final class Counter: @unchecked Sendable {
        private let lock = NSLock()
        private var value = 0
        func next() -> Int { lock.withLock { value += 1; return value } }
        var count: Int { lock.withLock { value } }
    }

    @Test("Concurrent requests share one refresh")
    func singleFlight() async throws {
        let (store, keychain) = makeStore()
        defer { try? keychain.delete("refresh_token") }
        let calls = Counter()
        await store.setRefresher { _ in
            try await Task.sleep(for: .milliseconds(50))
            return self.tokens(calls.next() + 1)
        }
        try await store.signedIn(tokens(1, expiresIn: 10)) // inside the 60 s skew → stale

        let results = try await withThrowingTaskGroup(of: String.self) { group in
            for _ in 0..<8 { group.addTask { try await store.accessToken() } }
            return try await group.reduce(into: [String]()) { $0.append($1) }
        }
        #expect(calls.count == 1)
        #expect(Set(results) == ["access_2"])
    }

    @Test("A rejected refresh token signs out; a network error doesn't")
    func refreshFailures() async throws {
        let (store, keychain) = makeStore()
        defer { try? keychain.delete("refresh_token") }
        try await store.signedIn(tokens(1, expiresIn: 0))

        await store.setRefresher { _ in throw URLError(.notConnectedToInternet) }
        await #expect(throws: URLError.self) { try await store.accessToken() }
        #expect(await store.hasStoredSession)

        await store.setRefresher { _ in throw SessionStore.SessionError.expired }
        await #expect(throws: SessionStore.SessionError.expired) { try await store.accessToken() }
        #expect(await !store.hasStoredSession)
    }
}
