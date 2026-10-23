# Prerequisites: verified before the build started

**Checked:** 2026-10-23, on the development Mac and against the live services. ✅ in place · ⚠️ works with a caveat · ❌ missing (with who or what unblocks it).

## API versioning: the change every client must make

The Platform API no longer puts its version in the URL (API v1.7.0; spec `1.0.0-draft.9`, API v1.8.0):

| Before | Now |
|---|---|
| `https://api.substratalapps.com/v1/users/me` | `https://api.substratalapps.com/users/me` |
| version implied by the path | `Substratal-Version: 1` request header, **required** |

Verified on production on 2026-10-23:

| Request | Result |
|---|---|
| `GET /health` (exempt from the header) | `200 {"status":"ok"}` |
| `GET /v1/health` | `404`: the old prefix is gone, with no redirect |
| `GET /permissions` without the header | `400 api_version_required`, `details.supported: ["1"]` |
| `GET /permissions` with `Substratal-Version: 1`, no token | `401 unauthenticated`, and the response echoes `substratal-version: 1` |

In this app: the base URL is the host root (`APIEnvironment.baseURL`). `APIVersion.current` is a compile-time constant, and `VersionMiddleware` stamps the header on every request, including the exempt ones, which is harmless. It also records `Deprecation`/`Sunset` and `400 unsupported_api_version` in `APIVersionMonitor`, which drives the GLB-03 banners. Unit tests cover each of these. The Help Center documents the scheme for integrators ([help/api/versioning.md](../help/api/versioning.md)).

## Development machine

| Item | Status | Detail |
|---|---|---|
| macOS | ✅ | 26.6.2 (the app targets macOS 15+, tests on 26) |
| Xcode | ✅ | 27.0 (27A266a), macOS 27.0 SDK |
| Swift | ✅ | 6.4; the project builds in Swift 6 language mode with complete concurrency checking |
| XcodeGen | ✅ | 2.46.0, installed with Homebrew during this check. The `.xcodeproj` is generated from `project.yml` and not committed. |
| swift-openapi-generator | ✅ | 1.14.2 (SwiftPM). Generates and compiles the **whole** spec: 124 operations, about 53k lines. |
| Ruby + Bundler | ✅ | rbenv; `help/Gemfile` pins `github-pages` 232, the same as the API docs site |
| Go | ⚠️ | 1.24.4 installed; the API needs 1.26, which `go` downloads automatically (`GOTOOLCHAIN=auto`). Only needed to run the API locally. |
| Docker + Compose | ✅ | 20.10.20 / v2.12.0. Runs the API's Postgres, LocalStack and Mailpit. |
| GitHub CLI | ✅ | Signed in as `Adron` |

## Signing and distribution

| Item | Status | Unblocks |
|---|---|---|
| Apple Development certificate | ✅ | Team `BJA9558E4B` (Adron B Hall); local Debug builds are signed with it |
| Bundle ID `com.substratalapps.hub` | ⚠️ **decide** | Chosen here; nothing in the specs or the iOS repo fixes it yet. iOS must use the **same** ID (Universal Purchase), because `app_hub` has one APNs topic (CLIENT-ARCHITECTURE §2). Confirm, then register it as an App ID. |
| Registered App ID + provisioning profile | ❌ | The data-protection Keychain (device-only refresh token), Push Notifications and Associated Domains. Until then, a local build stores the session in the login keychain instead (`KeychainStore` falls back on `errSecMissingEntitlement`). |
| **Developer ID Application** certificate | ❌ | Notarized direct-download builds (the plan's distribution route). Only Apple Development is installed. |
| Notarization credentials (App Store Connect API key) | ❌ | `notarytool` in CI. Store as GitHub secrets. |
| Sparkle update feed host (`downloads.substratalapps.com`) | ❌ | Doesn't resolve. Can start as a GitHub Release asset plus an appcast on Pages. |

## Repositories and publishing

| Item | Status | Detail |
|---|---|---|
| This repo's GitHub remote | ❌ **needs you** | `CompositeCode/substratalapps-macos` doesn't exist and the local repo has no remote or commits. Creating it and pushing is the one step left before CI and the Help Center go live. |
| GitHub Pages for the Help Center | ❌ | Enable after the first push: Settings → Pages → Source: **GitHub Actions**. The site publishes at `https://compositecode.github.io/substratalapps-macos/`, the address the app's Help menu uses (`SubstratalHelpBaseURL` in `project.yml`). |
| API repo `openapi.yaml` (raw, `main`) | ✅ | `200`. `scripts/sync-openapi.sh` vendors it; a scheduled workflow keeps it current. |
| Specs repo | ✅ | Up to date (`cebf679`, targets API v1.8.0). `scripts/import-screens.rb` imports its 75 macOS screens. |

## The API, for this app

| Item | Status | Detail |
|---|---|---|
| Production API | ✅ | `https://api.substratalapps.com`, header versioning live |
| Every operation this app's MVP needs | ✅ | Users, entitlements, roles, applications, keys, webhooks, tenants, audit, organizations, notifications, billing |
| Local API devserver | ✅ | Verified end to end from a scratch clone: the app signs in, loads Capabilities (all 13 superadmin permissions), lists users, and resumes its session after a relaunch. |
| Superadmin password (go-live [#20](https://github.com/CompositeCode/substratalapps.com/issues/20)) | ✅ | Closed: staff can sign in to production |
| Alert emails [#21](https://github.com/CompositeCode/substratalapps.com/issues/21), SES out of sandbox [#22](https://github.com/CompositeCode/substratalapps.com/issues/22) | ❌ | Invitation, verification and reset emails reach real inboxes |
| Stripe [#23](https://github.com/CompositeCode/substratalapps.com/issues/23) | ❌ | Plan & Billing (BIL-*) against production |
| Push credentials [#24](https://github.com/CompositeCode/substratalapps.com/issues/24), register `app_hub` [#25](https://github.com/CompositeCode/substratalapps.com/issues/25) | ❌ | Inbox push and device registration (NTF-*) |
| `dashboard.substratalapps.com` | ❌ | Doesn't resolve. Needed for Universal Links (`apple-app-site-association`), the forgot-password / verify-email / invitation pages, and Stripe return URLs. Owned by the web Hub. |
| Staff MFA enforcement | ❌ | API G13 [#50](https://github.com/CompositeCode/substratalapps.com/issues/50); the app can nudge but not enforce |
| Application retirement | ❌ | API G15 [#52](https://github.com/CompositeCode/substratalapps.com/issues/52) |
| Capabilities in one call, feature flags | ❌ | API G11 [#48](https://github.com/CompositeCode/substratalapps.com/issues/48); the app makes 5 calls and uses built-in flag defaults until then |

## Scope decision that changed since the plan

The specs repo now assigns the **Operations console to the web Hub only** (PRODUCT-SPEC §2a, OPEN-QUESTIONS #27). This app builds the Hub's Personal, Administration and Developer sections, and a test (`noConsoleScreens`) keeps console screens out of its catalog. See the update box at the top of [PLAN-management-app.md](PLAN-management-app.md).
