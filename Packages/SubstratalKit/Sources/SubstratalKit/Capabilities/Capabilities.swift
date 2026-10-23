import Foundation

/// What the signed-in person can see and do, computed from the API
/// (CLIENT-ARCHITECTURE §5). Navigation and every action button read only from
/// this; the server stays the authority, and a `403` triggers a refresh.
public struct Capabilities: Equatable, Sendable {
    /// Union of the permission keys on the person's platform Roles.
    public var platformPermissions: Set<String>
    public var ownedApplicationIDs: [String]
    public var ownedTenantIDs: [String]
    public var adminOfOrganizationIDs: [String]
    /// Feature flags: remote config once the API has it (API issue #48, G11);
    /// a `404`/`501` from a gated endpoint turns its flag off for the session.
    public var flags: Set<String>

    public init(
        platformPermissions: Set<String> = [],
        ownedApplicationIDs: [String] = [],
        ownedTenantIDs: [String] = [],
        adminOfOrganizationIDs: [String] = [],
        flags: Set<String> = Capabilities.defaultFlags
    ) {
        self.platformPermissions = platformPermissions
        self.ownedApplicationIDs = ownedApplicationIDs
        self.ownedTenantIDs = ownedTenantIDs
        self.adminOfOrganizationIDs = adminOfOrganizationIDs
        self.flags = flags
    }

    /// Signed out, or not loaded yet: personal screens only.
    public static let none = Capabilities()

    /// Flags on by default for this build (CLIENT-ARCHITECTURE §10). Phase 3
    /// features (`sso`, `passkeys`, `hosted_launch`) stay off.
    public static let defaultFlags: Set<String> = [
        "organizations", "org_grants", "app_profiles", "app_settings", "app_roles", "webhooks",
        "notifications", "push", "push_credentials", "send_notifications", "billing",
        "tier_changes", "app_registration_self_service", "audit_export", "scim",
    ]

    public func has(_ permission: String) -> Bool { platformPermissions.contains(permission) }

    public var ownsApps: Bool { !ownedApplicationIDs.isEmpty }

    /// INFORMATION-ARCHITECTURE §2, per sidebar item.
    public func isVisible(_ rule: String) -> Bool {
        switch rule {
        case "always":
            return true
        case "access":
            return has("entitlements.manage") || ownsApps
        case "developer":
            return ownsApps || !ownedTenantIDs.isEmpty
                || ["applications.manage", "api_keys.manage", "webhooks.manage", "tenants.manage"].contains(where: has)
        case "tenant":
            return !ownedTenantIDs.isEmpty || has("tenants.manage")
        default:
            if rule.hasPrefix("flag:") { return flags.contains(String(rule.dropFirst(5))) }
            if rule.hasPrefix("perm:") { return has(String(rule.dropFirst(5))) }
            return false
        }
    }

    public func isVisible(_ section: SidebarSection) -> Bool {
        switch section {
        case .personal:
            return true
        case .administration:
            return ["users.list", "entitlements.manage", "roles.manage", "audit.view", "notifications.send"].contains(where: has)
                || ownsApps
        case .developer:
            return isVisible("developer")
        }
    }
}
