import Foundation
import SubstratalAPI

/// Computes `Capabilities` on sign-in and on every foreground refresh, from the
/// calls CLIENT-ARCHITECTURE §5 lists. One call per fact, in parallel. A single
/// `GET /users/me/capabilities` would replace all of this (API issue #48).
public struct CapabilitiesLoader: Sendable {
    let client: Client

    public init(client: Client) { self.client = client }

    public func load(userID: String) async throws -> Capabilities {
        async let assignments = platformRoleIDs()
        async let permissionsByRole = platformRolePermissions()
        async let apps = ownedApplicationIDs()
        async let tenants = ownedTenantIDs(userID: userID)
        async let orgs = adminOrganizationIDs()

        let roleIDs = try await assignments
        let byRole = try await permissionsByRole
        let permissions = roleIDs.reduce(into: Set<String>()) { result, id in
            result.formUnion(byRole[id] ?? [])
        }
        return Capabilities(
            platformPermissions: permissions,
            ownedApplicationIDs: try await apps,
            ownedTenantIDs: try await tenants,
            adminOfOrganizationIDs: try await orgs
        )
    }

    /// `GET /users/me/roles`: platform assignments have no `application_id`.
    private func platformRoleIDs() async throws -> [String] {
        let output = try await client.roles_listForUser(
            path: .init(id: "me"),
            query: .init(limit: 100),
            headers: .init(substratalVersion: APIVersion.current)
        )
        guard case .ok(let ok) = output else { throw APIProblem.from(output) }
        return (try ok.body.json.value2.data ?? [])
            .filter { $0.applicationId == nil }
            .compactMap(\.roleId)
    }

    /// `GET /roles?scope=platform`: role → permission keys. `403` means the
    /// person holds no platform permissions, which is an answer, not an error.
    private func platformRolePermissions() async throws -> [String: [String]] {
        let output = try await client.roles_list(
            query: .init(limit: 100, scope: "platform"),
            headers: .init(substratalVersion: APIVersion.current)
        )
        switch output {
        case .ok(let ok):
            let roles = try ok.body.json.value2.data ?? []
            return Dictionary(
                roles.compactMap { role in role.value2.id.map { ($0, role.value1.permissions) } },
                uniquingKeysWith: { first, _ in first }
            )
        case .undocumented(statusCode: 403, _):
            return [:]
        default:
            throw APIProblem.from(output)
        }
    }

    /// `GET /applications?owned=true`.
    private func ownedApplicationIDs() async throws -> [String] {
        let output = try await client.applications_list(
            query: .init(limit: 100, owned: true),
            headers: .init(substratalVersion: APIVersion.current)
        )
        guard case .ok(let ok) = output else { throw APIProblem.from(output) }
        return (try ok.body.json.value2.data ?? []).compactMap(\.id)
    }

    /// `GET /tenants`, narrowed to the ones this person owns.
    private func ownedTenantIDs(userID: String) async throws -> [String] {
        let output = try await client.tenants_list(
            query: .init(limit: 100, ownerUserId: userID),
            headers: .init(substratalVersion: APIVersion.current)
        )
        switch output {
        case .ok(let ok): return (try ok.body.json.value2.data ?? []).compactMap(\.id)
        case .undocumented(statusCode: 403, _): return []
        default: throw APIProblem.from(output)
        }
    }

    /// `GET /organizations` → the ones where `my_role = org_admin`.
    private func adminOrganizationIDs() async throws -> [String] {
        let output = try await client.organizations_list(
            query: .init(limit: 100),
            headers: .init(substratalVersion: APIVersion.current)
        )
        switch output {
        case .ok(let ok):
            return (try ok.body.json.value2.data ?? [])
                .filter { $0.myRole == .orgAdmin && $0.myMembershipStatus == .active }
                .compactMap(\.id)
        case .undocumented(statusCode: 403, _): return []
        default: throw APIProblem.from(output)
        }
    }
}
