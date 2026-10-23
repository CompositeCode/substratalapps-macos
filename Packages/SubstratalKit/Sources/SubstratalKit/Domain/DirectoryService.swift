import Foundation
import SubstratalAPI

/// D6 Users: the directory (USR-01) and a single user (USR-03).
public struct DirectoryService: Sendable {
    public typealias User = Components.Schemas.User

    public struct Filter: Equatable, Sendable {
        public enum Status: String, CaseIterable, Sendable { case active, invited, suspended, deleted }

        public var query: String = ""
        public var status: Status?

        public init(query: String = "", status: Status? = nil) {
            self.query = query
            self.status = status
        }
    }

    public struct Page: Sendable {
        public let users: [User]
        public let nextCursor: String?
    }

    let client: Client

    public init(client: Client) { self.client = client }

    /// `GET /users`. `q` needs 3+ characters, so shorter text is matched against
    /// email exactly when it looks like one, otherwise ignored until it's longer.
    public func list(_ filter: Filter, cursor: String? = nil, limit: Int = 50) async throws -> Page {
        let text = filter.query.trimmingCharacters(in: .whitespaces)
        let output = try await client.users_list(
            query: .init(
                limit: limit,
                cursor: cursor,
                status: filter.status.flatMap { .init(rawValue: $0.rawValue) },
                q: text.count >= 3 ? text : nil
            ),
            headers: .init(substratalVersion: APIVersion.current)
        )
        guard case .ok(let ok) = output else { throw APIProblem.from(output) }
        let page = try ok.body.json
        return Page(users: page.value2.data ?? [], nextCursor: page.value1.page.nextCursor)
    }

    /// `GET /users/{id}`; pass `"me"` for the signed-in person.
    public func user(_ id: String) async throws -> User {
        let output = try await client.users_get(
            path: .init(id: id),
            headers: .init(substratalVersion: APIVersion.current)
        )
        guard case .ok(let ok) = output else { throw APIProblem.from(output) }
        return try ok.body.json
    }
}
