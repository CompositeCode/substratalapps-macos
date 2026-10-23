# Substratal Hub for macOS

The native macOS client for the [Substratal Apps Platform API](https://compositecode.github.io/substratalapps.com/): the Hub that staff and app developers use to run the platform (users, access, roles, Applications, API keys, webhooks, tenants and the audit log), plus every person's own apps, inbox, account and plan.

- **UI spec:** [substratalapps-applications-specs → macOS](https://compositecode.github.io/substratalapps-applications-specs/) (75 screens, the source of truth for screens, copy and behavior)
- **Help Center:** [`help/`](help/), published to [compositecode.github.io/substratalapps-macos](https://compositecode.github.io/substratalapps-macos/)
- **Plans:** [docs/PLAN-management-app.md](docs/PLAN-management-app.md) · [docs/PLAN-api-gaps.md](docs/PLAN-api-gaps.md) · [docs/PREREQUISITES.md](docs/PREREQUISITES.md)

## Status

**Skeleton.** Every screen in the spec is reachable, and most show a placeholder linking to their spec and help page. Built so far:

| | |
|---|---|
| Shell | Sidebar (Personal · Administration · Developer) gated by Capabilities, Go menu shortcuts, Help menu, multiple windows, deep links (`substratal://…`) |
| AUTH-01/02 | Sign in, two-factor (TOTP or recovery code), session in the Keychain with single-flight token refresh, resume on relaunch |
| USR-01 | User directory against the live API: search, status filter, paging |
| SET-01 | Appearance (5 light + 5 dark themes) and API connection (production or local devserver) |
| GLB-03 | API version banners: Update available (`Deprecation`/`Sunset`) and Update required (`unsupported_api_version`) |

Verified end to end against the API's local devserver: sign-in, Capabilities, the user directory, and session resume.

The **Operations console** (health, traffic, logs, alarms, cost) is web-only by spec decision (PRODUCT-SPEC §2a, OPEN-QUESTIONS #27), so it isn't part of this app.

## API versioning

The Platform API is versioned by header, not URL. Every request goes to the host root and sends `Substratal-Version: 1`:

```
GET https://api.substratalapps.com/users/me      ← no /v1
Substratal-Version: 1
```

`/v1/…` paths return `404`. The version is the compile-time constant `APIVersion.current` in `SubstratalKit`, and `VersionMiddleware` adds the header to every request, so no call can forget it. Moving to a new API version is a code change, never configuration. See [help/api/versioning.md](help/api/versioning.md).

## Layout

```text
.
├── App/                         The macOS app target: views and view models only
│   ├── SubstratalHubApp.swift   Scenes: main window, route windows, Settings
│   ├── AppModel.swift           Session, Capabilities, API environment, version status
│   ├── Navigation/              Split view, sidebar, menus/shortcuts, per-window routing
│   ├── Screens/                 One folder per area; ScreenHost maps routes to screens
│   └── Resources/               Assets (from the spec's brand-assets), entitlements
├── AppUITests/                  UI smoke tests
├── Packages/SubstratalKit/      Shared core (macOS now, iOS later)
│   ├── Sources/SubstratalAPI/   openapi.yaml → generated client (swift-openapi-generator, at build time)
│   └── Sources/SubstratalKit/   API middleware and versioning, sessions + Keychain, Capabilities,
│                                screen catalog + routes, help links, theme, domain services
├── help/                        Help Center (Jekyll + just-the-docs, the same stack as the API docs)
├── scripts/                     sync-openapi.sh, import-screens.rb, help-generate/build/check.rb
├── docs/                        Plans and the prerequisites check
├── project.yml                  XcodeGen definition (the .xcodeproj is generated, not committed)
└── .github/workflows/           ci.yml, help.yml, upstream-sync.yml
```

## Getting started

Requirements: Xcode 26 or later, macOS 15 or later, [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`), and Ruby with Bundler for the Help Center.

```bash
make project     # generate SubstratalHub.xcodeproj
make build       # or open SubstratalHub.xcodeproj and run the SubstratalHub scheme
make run         # build and launch against production
make test        # SubstratalKit unit tests
make help-serve  # Help Center at http://localhost:4000/substratalapps-macos/
make check       # everything CI runs
```

The first build takes a few minutes: the API client is generated from the full spec (124 operations).

### Against a local API

Run the API repository's devserver (`make up && make migrate && make seed && make run` there), then:

```bash
make run API=http://localhost:8080
```

or choose **Settings → Connection → Local devserver** in the app. Each environment keeps its own session. Sign in with the seeded `ADMIN_EMAIL` / `ADMIN_PASSWORD` from that repo's `.env`.

### Signing

Debug builds sign with your Apple Development certificate (team set in `project.yml`). Without a provisioning profile, the session token is stored in the login keychain instead of the data-protection Keychain. Release builds need the registered App ID and a Developer ID certificate; see [docs/PREREQUISITES.md](docs/PREREQUISITES.md).

## Where things come from

Two upstreams feed this repo, and both are vendored by script, never edited by hand:

| File | From | Refresh |
|---|---|---|
| `Packages/SubstratalKit/Sources/SubstratalAPI/openapi.yaml`, `help/api/openapi.yaml` | API repo `docs/openapi.yaml` on `main` | `make sync-api` |
| `Packages/SubstratalKit/Sources/SubstratalKit/Resources/screens.json` | Specs repo `macos/SCREENS.md` | `make sync-screens` |

The screen catalog drives the sidebar, menus, routes and deep links, and generates one Help Center page per screen. The app's help links and the site therefore can't disagree, and CI checks that they don't.

## Documentation workflow

- **Every change to the app** that reaches `main` publishes a new Help Center version (`help.yml`). Screen pages, keyboard shortcuts, "Coming soon" banners, release notes (from `CHANGELOG.md`) and the API reference are generated from the code and the vendored spec each time.
- **Every API change** is picked up by `upstream-sync.yml`, which runs daily, by hand, or on a `repository_dispatch` from the API repo. It opens a pull request that updates the generated client and the docs together. CI must build the app against the new spec before it can merge.
- **Every published version** is frozen at `/versions/<n>/`, labelled with the app version and Platform API version it describes.

Update `CHANGELOG.md` under **Unreleased** with every change people will notice.

## Known gaps in the skeleton

- Sign-in shows in the main window; the spec's separate fixed-size sign-in `Window` is still to do.
- Feature flags are built-in defaults until the API serves them (API issue #48).
- Push (APNs), Universal Links and Touch ID re-open lock need the provisioning prerequisites.
- No command palette (⌘K) or inspector yet.

## License

[MIT](LICENSE).
