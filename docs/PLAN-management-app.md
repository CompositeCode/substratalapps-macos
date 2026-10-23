# Plan 1 — Substratal Console for macOS (management app for the API tier)

**Status:** proposal, 2026-10-21
**Target:** `https://api.substratalapps.com` (live; `GET /health` → `200` on 2026-10-21)
**Inputs reviewed:** API repo `CompositeCode/substratalapps.com` (spec `openapi.yaml` 1.0.0-draft.3 / docs v1.4.0, 118 operations, `plan-remaining.md`, `infra/README.md`, `infra/terraform/prod`) and the client spec package `CompositeCode/substratalapps-applications-specs` (macOS `PLATFORM-SPEC.md`, `SCREENS.md`, `00-shared/*`).
**Companion:** [PLAN-api-gaps.md](PLAN-api-gaps.md) — what the API needs before this app can do everything below.

> ### Update, 2026-10-23: read this first
>
> Three things changed after this plan was written. Where they conflict with the sections below, this box wins.
>
> 1. **API versioning moved to a header.** The URL no longer carries a version. Every endpoint is at the host root (`https://api.substratalapps.com/users/me`), and every request sends `Substratal-Version: 1`. `/v1/…` paths now return `404`. A request without the header gets `400 api_version_required`; an unserved version gets `400 unsupported_api_version`. Deprecations arrive as `Deprecation`/`Sunset` response headers, at least 6 months ahead (API v1.7.0, spec `1.0.0-draft.9`). Paths in this document have been updated to match. The app implements it in `SubstratalKit` (`APIVersion`, `VersionMiddleware`, `APIVersionMonitor`) and shows GLB-03 Update available / Update required.
> 2. **The Operations console is web-only.** The specs repo decided (PRODUCT-SPEC §2a, OPEN-QUESTIONS #27) that the console screens (OPS-01…07, SEC-01, CFG-01/02, RPT-01, INT-01) are built by the **web Hub**, which reads AWS through a same-origin Ops gateway. Native apps, macOS included, skip them. So §3's OPERATIONS section, §4.5–4.11 and §6.2's `ops` Lambda describe the web Hub's console, not this app. The macOS app is the Hub's Personal, Administration and Developer sections (75 screens). It links to the web console where useful.
> 3. **The API gaps are now issues.** Plan 2 became `[api-gaps]` issues G1–G21 in the API repo (#38–#57, #65). Already shipped: G1 CORS (#38), G14 revoke all sessions (#51), G17 filter users by role (#54), G19 audit export (#56, via #33), plus test-user expiry (#30), self-service app registration (#32) and SCIM (#34). The proposed `ops.view`/`ops.manage` permissions became `operations.view`/`operations.manage` (G10, #47).
>
> What's built so far, and what's needed before the rest can be, is in [PREREQUISITES.md](PREREQUISITES.md) and the [README](../README.md).

---

## 0. Summary

- **Can we start building now?** Yes, for about 70% of the app. Everything about the *objects* the API manages is already exposed and implemented: users, access/entitlements, roles, applications, API keys, webhooks, push credentials, tenants, organizations, billing and audit. Building those screens is unblocked today.
- **What's missing** is everything about the *system itself*: health beyond a shallow `{"status":"ok"}`, usage and performance metrics, logs, alarms, platform configuration, scheduled-job visibility, and cost. None of this is exposed through the API. It lives only in CloudWatch, Terraform variables and environment variables. That's Plan 2.
- **Recommended shape:** build this app as the macOS **Substratal Hub** already specified in the specs repo (same shell, routes, components and themes), **admin-first**. Add one new sidebar section, **Operations**, backed by a small new `ops` Lambda in the API repo. The Hub spec already hides Administration and Developer from people without the rights, so one app serves both the staff console and the end-user hub. Two codebases would mean two auth stacks and two spec trees for no gain.
- **Stack:** Swift 6 / SwiftUI (macOS 15+), `swift-openapi-generator`, Swift Charts, Keychain, and a shared `SubstratalKit` package. It ships as a notarized Developer ID build with Sparkle, hosted on the existing S3 + CloudFront. **The app adds no servers.** The only new AWS piece is one Lambda behind the existing API Gateway, at roughly $1–3/month.

---

## 1. Positioning: Console vs. Hub

The specs repo defines the macOS app as the **Substratal Hub**, a 75-screen client for every persona, from end users through superadmins. The request here is a **management app for the API**. These aren't in conflict:

| Option | Verdict |
|---|---|
| A. Separate "Console" app, admin only | Duplicates sign-in, session, Capabilities, theming, and the entire Administration and Developer screen set from the spec. A second bundle id also needs a second APNs topic, because `app_hub` has one (spec OPEN-QUESTIONS #3). |
| **B. The Hub, built admin-first, plus a new Operations section** ✅ | One codebase, and one `SubstratalKit` shared with iOS. Personal screens (Home, Inbox, Plan & Billing) still ship because the spec requires them, but they come later in the build order. Operations is gated by a new platform permission (`ops.view`, see Plan 2), so end users never see it. |

The rest of this plan assumes **B**. "Console" below means the Administration, Developer and Operations sections of the Hub.

---

## 2. Personas the Console serves

These come from the spec, plus one new persona.

| Persona | Platform permissions | Console sections |
|---|---|---|
| **Superadmin** (platform owner, protected) | all 13 | everything |
| **Operator / SRE** *(new)* | `ops.view`, `ops.manage` *(new, Plan 2)*, `audit.view` | Operations, Audit |
| **Support** | `users.list`, `entitlements.manage`, `audit.view`, `tenants.manage`, `billing.manage` | Users, Access, Audit, Tenants, user notifications |
| **Billing admin** | `billing.manage`, `billing.refund`, `audit.view`, `users.list` | Users (read), Billing, Audit |
| **App owner (developer)** | none; owns ≥ 1 Application | Applications (own), API Keys (own app), Webhooks (own app), Access (confined), Usage (own app) |

---

## 3. Information architecture

This extends `00-shared/INFORMATION-ARCHITECTURE.md`. The PERSONAL, ADMINISTRATION and DEVELOPER sections are unchanged. **OPERATIONS** is new.

```
Substratal Hub (macOS)
├── PERSONAL            Home · Inbox · Organizations · Account · Plan & Billing · Settings      (spec, unchanged)
├── OPERATIONS  (new)   /ops
│   ├── Overview        /ops                    OPS-01  system status board
│   ├── Usage           /ops/usage              OPS-02  traffic & analytics (by app / key / route / status)
│   ├── Performance     /ops/performance        OPS-03  latency, errors, cold starts, DB capacity
│   ├── Logs            /ops/logs               OPS-04  request + security log search
│   ├── Alerts          /ops/alerts             OPS-05  alarms, alert rules, notification routing
│   ├── Jobs & Queues   /ops/jobs               OPS-06  scheduled jobs, webhook/push queues, DLQ
│   ├── Configuration   /ops/config             OPS-07  platform settings, rate limits, feature flags, maintenance
│   ├── Integrations    /ops/integrations       OPS-08  Slack/PagerDuty/email routes, platform webhooks, MCP
│   ├── Cost            /ops/cost               OPS-09  AWS spend vs. budgets
│   └── Releases        /ops/releases           OPS-10  deployed version, migrations, docs version
├── ADMINISTRATION      Users · Access · Roles · Audit Log · Send notification                 (spec D6–D8, D12, NTF-06)
└── DEVELOPER           Applications · API Keys · Webhooks · Tenant                             (spec D9–D11)
```

Sidebar order on macOS: Personal, then **Operations**, then Administration, then Developer. Operations goes above the spec's sections because it's what an operator opens the app for.

**Visibility:** Operations shows when the person holds `ops.view`. Superadmins hold it through the seed role update in Plan 2. Until the ops endpoints exist, the section is hidden behind the `operations` flag; a `404` or `501` from `/ops/*` turns it off, the same pattern the spec uses.

**Shortcuts** (added to the spec's table): ⇧⌘1 … ⇧⌘9 for Overview … Cost, under Go → Operations.

**SF Symbols:** Overview `gauge.with.dots.needle.67percent` · Usage `chart.bar.xaxis` · Performance `speedometer` · Logs `text.magnifyingglass` · Alerts `bell.and.waves.left.and.right` · Jobs `clock.arrow.2.circlepath` · Configuration `slider.horizontal.below.square.filled.and.square` · Integrations `puzzlepiece.extension` · Cost `dollarsign.gauge.chart.leftthird.topthird.rightthird` · Releases `shippingbox.and.arrow.backward`.

---

## 4. Feature set

Each feature lists its screens, the API it uses, and a readiness flag:
**✅ Ready** (the API exists today) · **🟡 Partial** (works with a workaround; Plan 2 improves it) · **🔴 Blocked** (needs Plan 2).

### 4.1 Sign-in and admin session security

| Feature | Screens | API | Ready |
|---|---|---|---|
| Email + password sign-in, TOTP challenge | AUTH-01/02 | `POST /auth/login`, `/auth/mfa/verify` | ✅ |
| Session refresh (single-flight `actor SessionStore`), refresh token in Keychain (`AfterFirstUnlockThisDeviceOnly`, not synchronizable) | — | `/auth/token/refresh`, `/auth/logout` | ✅ |
| Touch ID re-open lock and 15-min idle auto-lock, **on by default for anyone with a platform permission** | GLB-03 | local | ✅ |
| Own sessions list and sign out others | ACC-04 | `/users/{id}/sessions` | ✅ |
| **Enforce MFA for platform-role holders**: the Console refuses admin sections until TOTP is on | ACC-05 | client-side now; server enforcement in Plan 2 §4 | 🟡 |
| Step-up re-authentication before destructive admin actions (suspend user, revoke key, rotate secrets, delete role) | confirm sheet with TOTP field | Plan 2 §4 (`/auth/step-up`) | 🔴 (client-side re-prompt meanwhile) |
| Passkeys / SSO for staff | AUTH-01 | SSO returns `501` (Phase 3) | 🔴 flag off |

**Rule:** the Console never authenticates with an API key. Every admin action is a User session, so audit `actor_type` is always `user`. API keys also can't manage keys (`400 user_token_required`).

### 4.2 User and role management (authentication management, roles and permissions)

| Feature | Screens | API | Ready |
|---|---|---|---|
| User directory: search (`q`, `email`), filter by status / app / org / created range, `Table` with multi-select | USR-01 | `GET /users` | ✅ |
| Invite, resend invitation, create test-mode users | USR-02 | `POST /users`, `/users/{id}/invitation` | ✅ |
| User overview, profile, suspend / reactivate, delete, export, erasure | USR-03/05 | `/users/{id}`, `/suspend`, `/export`, `/erasure-requests` | ✅ |
| Per-user sessions: view and revoke | USR-04 | `/users/{id}/sessions/{sessionId}` | ✅ |
| Per-user access ("Is the app on?"), grant, turn off, "Why?" | ACX-01..04 | `/users/{id}/entitlements`, `/entitlements`, `effective-permissions` | ✅ |
| All access across the platform | ACX-05 | `GET /entitlements` | ✅ |
| Roles: list, detail, new, edit permission checklist, delete; seed roles read-only | ROL-01..03 | `/roles`, `/permissions` | ✅ |
| Assign or remove roles per user | ROL-04 | `/users/{id}/roles` | ✅ |
| "People with this role" on a role | ROL-02 | needs `GET /users?role_id=` (Plan 2 §7) | 🔴 hidden |
| Bulk suspend, grant or assign | USR-01, ACX-05 | one request per row, 4 in parallel (spec OQ #6) | 🟡 |
| Force sign-out of a user everywhere | USR-04 | loop over sessions | 🟡 (Plan 2 adds a single call) |

### 4.3 Application management (add, configure, review, remove)

| Feature | Screens | API | Ready |
|---|---|---|---|
| Application list: all, by owner, by `review_status`, by `access_tier` | APL-01 | `GET /applications` | ✅ |
| Register an application (platform-admin-only today; this is "add to the system") | APL-02 | `POST /applications` | ✅ |
| Overview, edit, launch URL, icon, visibility, `default_app_role`, `available_app_roles` | APL-03 | `GET/PATCH /applications/{id}` | ✅ |
| Settings schema editor (JSON drop, validation, stale-override counts) | APL-04 | `PATCH settings_schema`, `settings_schema_stats` | ✅ |
| App permissions and app roles | APL-05 | `/applications/{id}`, `/roles?scope=` | ✅ |
| Review queue: approve / reject with notes / **suspend** (the kill switch) | APL-06 | `PATCH review_status` (+ `?review_status=pending_review`) | ✅ |
| Push credentials (APNs `.p8`, FCM JSON, VAPID) | APL-07 | `/applications/{id}/push-credentials` | ✅ |
| Who has access, and usage for this app | APL-03 tabs | `GET /users?application_id=`, Usage (§4.6) | ✅ / 🔴 |
| **Remove / retire an application** | APL-03 ⋯ menu | **No DELETE or archive today**. Suspend is the only off-switch. | 🔴 Plan 2 §6 |

### 4.4 API key management (clients and internal use)

What the API already provides covers this well: platform vs. app scope, `live`/`test` modes, `intended_use: service|agent`, `restrict_destructive`, `expires_at`, `secret_hint`, `last_used_at`, rotation, and soft revoke.

| Feature | Screens | API | Ready |
|---|---|---|---|
| Key list with filters (scope, mode, intended use, include inactive); columns for hint, last used, expires, creator | KEY-01 | `GET /api-keys` | ✅ |
| Create a key. The permission picker only offers permissions the creator holds, and the agent preset turns on `restrict_destructive`. | KEY-02 | `POST /api-keys` | ✅ |
| **Secret reveal, exactly once**, in a sheet with `NSWindow.sharingType = .none`. Copy puts it on the clipboard marked sensitive, auto-cleared after 60 s. It's never persisted, logged or cached. | KEY-03 | response of create/rotate | ✅ |
| Detail: edit name, permissions, `restrict_destructive`; rotate; revoke (step-up) | KEY-04 | `PATCH`, `/rotate`, `DELETE` | ✅ |
| Hygiene panel: keys never used, unused for 30+ days, expiring within 14 days, `service` keys holding destructive permissions, platform keys with broad permissions | KEY-01 filter chips | derived client-side from `last_used_at`, `expires_at`, `permissions` | ✅ |
| Per-key request volume, error rate and 429s | KEY-04 Usage tab | Plan 2 §2 | 🔴 |
| *Optional, Phase 3:* "Deliver to AWS Secrets Manager" for **internal** platform keys, so a secret goes straight from the create response into the consuming service's secret and never touches a clipboard | KEY-03 | needs the `ops` Lambda (Plan 2 §8) | 🔴 |

**How the client handles keys:** the Console only manages keys. It never stores or uses one. App developers' backends keep their own keys. Substratal's internal services, such as the billing handler and the smoke test, already read theirs from Secrets Manager or GitHub secrets.

### 4.5 Operations: monitoring dashboard (OPS-01 Overview)

A single status board on a `Grid` of tiles. It refreshes every 30 s while the window is visible and pauses when occluded (`NSWindow.occlusionState`).

| Tile | Data | Ready |
|---|---|---|
| API status (shallow) | `GET /health` | ✅ |
| Component health: Aurora, Data API, KMS, SQS, SES, Stripe, push providers | `GET /ops/health` | 🔴 |
| Requests / 5xx / 4xx / 429 (last 1 h, sparkline) | `GET /ops/metrics` | 🔴 |
| p50/p95 latency vs. NFR targets (150 ms hot paths) | same | 🔴 |
| Aurora ACU vs. max; Lambda throttles | same | 🔴 |
| Open alarms (count + list) | `GET /ops/alarms` | 🔴 |
| Webhook queue depth, DLQ, oldest pending delivery | `GET /ops/queues` | 🔴 |
| Security signals: failed logins, refresh-token reuse, destructive-blocked (these metric filters already exist in Terraform) | `GET /ops/metrics?set=security` | 🔴 |
| Month-to-date cost vs. warn and hard budgets | `GET /ops/cost` | 🔴 |
| Recent audit activity (last 20 events) | `GET /audit-events?limit=20` | ✅ |
| Pending reviews (apps), pending tier-change requests | `/applications?review_status=pending_review`, `/tenants/{id}/tier-change-requests` | ✅ |

The board ships in Phase A with the ✅ tiles and placeholder "Not available yet" tiles for the rest, so the screen exists early and fills in as Plan 2 lands.

### 4.6 Usage and analytics (OPS-02) and Performance (OPS-03)

- **Usage:** a time-range picker (1 h, 24 h, 7 d, 30 d, custom). It groups by **application · API key · route · status class · principal type**. Swift Charts stacked bars, plus a top-N `Table` (top keys, top apps, top 4xx routes, top 429 callers). Drilling into a row opens the key, app or route with the same chart filtered.
- **Performance:** latency percentiles per route template, error rate, Lambda duration and cold starts per function (api, mcp, stripe-webhook, webhook-worker, jobs), Aurora ACU and Data API errors.
- **Reports:** "Export CSV / JSON" via `fileExporter`, and a "Copy chart" image. A scheduled weekly summary is server-side (Plan 2 §5). The app doesn't run in the background to build reports.
- **Readiness:** 🔴 everything here needs Plan 2 §2–3. Raw access logs today don't carry the key, app or route template.

### 4.7 Logs (OPS-04)

- Query bar with structured filters: request id, status, route, principal (user / key), application, IP, and level. Time range. Results stream in a `Table`; selecting a row opens an inspector with the full JSON log line plus links to the user, key, app, and audit events sharing the `request_id`.
- Saved queries live in app preferences.
- The **security log** preset filters on `msg = "security"` (login, MFA challenge, refresh reuse, destructive blocked).
- **The app never holds AWS credentials.** It calls `GET /ops/logs`, which runs CloudWatch Logs Insights server-side with a bounded time range and a byte-scan cap. 🔴 Plan 2 §3.

### 4.8 Alerts and notifications (OPS-05)

- **Alarms:** list of CloudWatch alarms with state, history and the reason text. It covers the alarms that already exist (5xx, Lambda errors and throttles, Aurora near max, webhook DLQ, security metric filters) and those Plan 2 adds (budget, latency SLO, push failure rate).
- **Delivery to admins:** ops alarms become **platform notifications** to holders of `ops.view`. That reuses the API's existing inbox and APNs push to `app_hub`, so a Mac or iPhone gets a Time Sensitive notification with categories *Acknowledge* and *Open in Console*. The Dock badge shows the open-alarm count when the person prefers it to the unread count.
- **Rules:** edit thresholds for the user-tunable alarms (5xx rate, latency p95, 429 rate per key, DLQ depth, budget %). It also manages mute or snooze per alarm and routing (who gets what: email, push, Slack, PagerDuty).
- **Readiness:** 🔴 needs Plan 2 §5. The SNS topic emails `alarm_email` today, and nothing else.

### 4.9 Jobs and queues (OPS-06)

- Scheduled jobs (entitlement sweep, idempotency/rate-limit cleanup, audit archival, plan reconcile, and later the test-user expiry sweep) with their last run, duration, result, next run, and a **Run now** button (step-up).
- Webhook and push delivery queues: depth, age of oldest, DLQ count, and **Redrive DLQ**.
- Cross-webhook "failing deliveries" view. Today deliveries are only listable per webhook (`/webhooks/{id}/deliveries`), so a global view is 🟡: the app loops over webhooks until Plan 2 §3 adds a global query.
- Readiness: 🔴 for jobs and queues, 🟡 for deliveries.

### 4.10 Configuration (OPS-07)

Platform-wide settings that today live in environment variables, Terraform variables or Go constants:

| Group | Examples | Today |
|---|---|---|
| Rate limits | default per-principal limit, per-operation overrides, per-key overrides | Go constants + API Gateway stage throttle |
| Feature flags | `organizations`, `notifications`, `billing`, `sso`, `passkeys`, `app_registration_self_service`, `audit_export`, … (the list the client spec assumes is "remote config", which doesn't exist) | **none** |
| Sign-up policy | open / invite-only / closed; allowed email domains for staff | env |
| Security policy | require MFA for platform roles, session idle timeout, admin IP allowlist | not implemented |
| Maintenance mode | read-only mode with a message and `Retry-After` | not implemented |
| Email / push | sender address, push backend live/log (read-only display) | env |
| CORS origins | read-only display | env |

The UI is a `Form` per group in a 3-column layout (groups · settings · history). Every change requires `If-Match`, shows a diff confirm, writes an audit event, and offers a one-click revert to any previous version. 🔴 Plan 2 §1.

### 4.11 Integrations (OPS-08)

- **Platform webhooks** (`scope: platform`) already exist (WHK-01..04 ✅). Adding `ops.*` event types (Plan 2 §5) lets any external tool subscribe: alarms, deploys, config changes.
- **Built-in routes** for Slack incoming webhook, PagerDuty Events v2 and email. These are configured here but delivered server-side, so secrets stay in the API.
- **MCP server:** shows the `/mcp` endpoint, lists agent-intended keys, and links to the docs. ✅ (data comes from `/api-keys?intended_use=agent`).
- **Stripe:** read-only status (webhook endpoint health, last event received) through `/ops/health`. 🔴
- **GitHub:** a link to the release workflow and `[bespoke]` issues. Read-only. No GitHub token is stored in the app.

### 4.12 Audit and activity tracking (AUD-01/02, plus Activity tabs)

| Feature | API | Ready |
|---|---|---|
| Audit `Table` with filters: actor (user/key/system), action, target type/id, user, app, org, tenant, time range; inspector with before/after snapshot | `GET /audit-events` | ✅ |
| `Audit-Hot-Window-Start` banner ("Events before X are archived, contact support") | header | ✅ |
| Per-user Activity tab: events where the user is actor, plus events where they're the target | two `GET /audit-events` calls merged | ✅ |
| "My admin activity" (what I did) | `actor_id=me` | ✅ |
| Drag an event out as `.json` | client | ✅ |
| Export a range (CSV/JSONL) | Phase 3 `audit_export` | 🔴 |
| Free-text search, aggregation charts (actions per day per actor) | Plan 2 §7 | 🔴 |
| Audit of sensitive **reads** (viewing PII, data exports) | verify, Plan 2 §4 | ❓ |

### 4.13 Tenants, organizations, billing (admin side)

These are all in the spec and ✅ ready: tenant list and detail, tier-change requests approve/deny (BIL-04); organizations, members and seat grants (ORG-*); per-user and per-org subscription view and Stripe portal hand-off (BIL-01..03); staff "send notification" (NTF-06); a user's notifications and devices (NTF-05).

---

## 5. Interface design

The Console follows `macos/PLATFORM-SPEC.md` exactly: `NavigationSplitView`, Liquid Glass from standard controls, `Table` with an inspector for logs and audit, theme roles from `SubstratalTheme.swift`, and the 5 + 5 themes. Additions for Operations:

### 5.1 OPS-01 Overview (wireframe)

```
┌ Sidebar ─────────┬───────────────────────────────────────────────────────────────────────┐
│ OPERATIONS       │ Overview                         Last 1 h ▾   ⟳   ● All systems normal │
│ ▸ Overview       ├───────────────────────────────────────────────────────────────────────┤
│   Usage          │ ┌ API ───────┐ ┌ Requests ──────┐ ┌ Errors ───────┐ ┌ p95 latency ─┐ │
│   Performance    │ │ ● Healthy  │ │ 12.4k  ▁▂▃▅▃▂  │ │ 5xx 0.02%     │ │ 84 ms / 150  │ │
│   Logs           │ │ v1.4.0     │ │ +8% vs prev    │ │ 429 31        │ │ ▁▁▂▁▃▁       │ │
│   Alerts      2  │ └────────────┘ └────────────────┘ └───────────────┘ └──────────────┘ │
│   Jobs & Queues  │ ┌ Components ───────────────────────┐ ┌ Open alarms ───────────────┐ │
│   Configuration  │ │ Aurora     ● 0.5/4 ACU            │ │ ▲ webhooks-dlq   12 min    │ │
│   Integrations   │ │ Data API   ●   SQS ● depth 3      │ │ ▲ security-failed-logins   │ │
│   Cost           │ │ KMS ●  SES ● sandbox  Stripe ●    │ │            [View all]      │ │
│   Releases       │ │ APNs ●  FCM ●  Web Push ●         │ └────────────────────────────┘ │
│ ADMINISTRATION   │ └───────────────────────────────────┘ ┌ Cost (MTD) ────────────────┐ │
│   Users          │ ┌ Needs attention ──────────────────┐ │ $38.12 of $75 warn  ▓▓▓▓░░ │ │
│   Access …       │ │ 2 apps pending review   [Review]  │ └────────────────────────────┘ │
│ DEVELOPER        │ │ 1 tier change request   [Open]    │ ┌ Recent admin activity ─────┐ │
│   Applications   │ │ 3 keys expiring ≤ 14 d  [Keys]    │ │ dana  api_key.rotated  2m  │ │
│   API Keys …     │ └───────────────────────────────────┘ └────────────────────────────┘ │
└──────────────────┴───────────────────────────────────────────────────────────────────────┘
```

### 5.2 Patterns

- **Tiles** are `GroupBox`es with a `StatusBadge` (from the spec's `status-semantics.json`, extended with `healthy / degraded / down / unknown`). Every tile is a button that routes to its detail screen, and every tile has `.accessibilityElement(children: .combine)` with a spoken summary.
- **Charts:** Swift Charts only, using theme roles, never literal colours. Series colours come from `palette.chart1…6`, which need adding to `THEMES.md` for all 10 themes. Hover shows a `chartOverlay` tooltip, and ⌘C copies the underlying rows.
- **Time range** is one shared control in the toolbar principal position, encoded in the route (`/ops/usage?range=24h&group=key`) so windows restore and deep links share state.
- **Destructive ops actions** (Run job, Redrive DLQ, Maintenance mode on, Revoke key, Suspend app) use the spec's confirm pattern: name the object, add a TOTP field (step-up), and a destructive button style.
- **Live data:** polling only, visible-window-aware. No websockets, because API Gateway HTTP API plus Lambda doesn't offer them cheaply, and pushes cover the urgent alerts.
- **Menu bar extra** (opt-in, already in the spec) gains an Ops status dot plus an open-alarm count for `ops.view` holders.
- **Multi-window:** ⌘-double-click any app, key, user or log entry opens it in its own window via `WindowGroup(for: Route.self)`. Operators like the Overview on one display and Logs on another.

### 5.3 New screen IDs (to add to the specs repo)

OPS-01 Overview · OPS-02 Usage · OPS-03 Performance · OPS-04 Logs · OPS-05 Alerts (+ OPS-05b Alert rule) · OPS-06 Jobs & Queues · OPS-07 Configuration (+ OPS-07b Change history) · OPS-08 Integrations · OPS-09 Cost · OPS-10 Releases · APL-08 Retire application · KEY-05 Key usage tab.
These should go into `00-shared/SCREEN-SPECS.md`, `API-SCREEN-MAP.csv` and `INFORMATION-ARCHITECTURE.md` in the specs repo before build, keeping the spec as the source of truth.

---

## 6. Technology stack

### 6.1 The macOS app

| Concern | Choice | Why |
|---|---|---|
| Language / UI | **Swift 6** (strict concurrency), **SwiftUI** app lifecycle, AppKit bridges only where the spec names them | The spec's choice; native `Table`, `Inspector`, `NavigationSplitView`, and Liquid Glass for free on macOS 26 |
| Min OS | macOS 15 Sequoia; test on 26 | Spec |
| Shared core | Swift package **`SubstratalKit`** (shared with iOS): generated client, `SessionStore` actor, Capabilities, domain services, cache, theme | Spec; the iOS admin can reuse the Console logic later |
| API client | **`swift-openapi-generator`** + `swift-openapi-urlsession`, generated from the API repo's `docs/openapi.yaml`, pinned by spec version | One contract; a spec change becomes a compile error. Middleware handles bearer, refresh, `Idempotency-Key`, `If-Match`/`ETag`, `RateLimit-*`/`Retry-After`, and error-envelope decoding. |
| Networking | `URLSession` with one shared session, HTTP/2 connection reuse to API Gateway, `URLCache` off (explicit cache), `waitsForConnectivity`, request coalescing for identical in-flight GETs | Efficient on a high-latency link, and avoids duplicate polling from multiple windows |
| State | `@Observable` view models; per-screen state machine idle → loading → loaded / empty / error | Spec |
| Charts | **Swift Charts** | Native, accessible (Audio Graphs), themeable, no dependency |
| Persistence | Keychain (refresh token only); **SwiftData** cache for catalog, roles, permissions, and last-seen dashboard snapshots (fast cold launch, offline read-only); `UserDefaults` for saved log queries and layout | Spec |
| Security | Touch ID (`LAContext`), capture-excluded secret sheets, sensitive clipboard with auto-clear, App Sandbox + Hardened Runtime (network client only) | Spec |
| Push | APNs via the `app_hub` application (shared bundle id with iOS) | Spec; ops alarms reuse it |
| Updates / distribution | **Developer ID + notarization + Sparkle 2**. The DMG and the appcast are hosted on the existing S3 + CloudFront static-assets distribution under `downloads.substratalapps.com`. The Mac App Store build is deferred, because an internal admin tool gains nothing from MAS review. | Pennies per month and no new service |
| Build / CI | Xcode 26, an XcodeGen or Tuist project file (reviewable diffs), **GitHub Actions `macos-15` runner**: build, test, notarize (`notarytool` with an App Store Connect API key in GH secrets), publish to S3 through the existing OIDC deploy-role pattern | Same CI/OIDC model as the API |
| Tests | Swift Testing for `SubstratalKit`; snapshot tests per theme; XCUITest for the persona × sidebar matrix; **contract tests against the API's local devserver** (`make up && make run`) in CI | The API repo already runs everything locally with Docker Compose |
| Lint / format | `swift-format`, SwiftLint (strict on force unwraps and literal colours) | |

### 6.2 What goes into AWS for this app (keeping it cheap)

The Mac app is a client, so nothing about it runs in AWS except its download hosting. The ops data it needs comes from **one new Lambda in the existing API stack**:

```
Mac app ──HTTPS (Bearer, platform session)──▶ API Gateway (existing HTTP API)
                                               ├─ /*      → api Lambda (existing)
                                               └─ /ops/*  → ops Lambda (NEW, Go, arm64)
                                                                  ├─ CloudWatch GetMetricData / DescribeAlarms (read)
                                                                  ├─ CloudWatch Logs Insights StartQuery/GetQueryResults (read, capped)
                                                                  ├─ SQS GetQueueAttributes, DLQ redrive (ops.manage)
                                                                  ├─ Cost Explorer GetCostAndUsage (cached 6 h in Postgres)
                                                                  ├─ Scheduler/Lambda Invoke jobs (ops.manage)
                                                                  └─ Aurora via Data API (usage rollups, config, alert routes)
CloudWatch Alarm ─▶ SNS (existing) ─▶ ops Lambda ─▶ platform notification (existing inbox + APNs) + Slack/PagerDuty
```

| Why this shape | |
|---|---|
| **No AWS credentials on laptops** | Admins authenticate once, with the platform's own users, roles and MFA. Authorization is the API's existing `has_platform_permission` plus new `ops.*` permissions, and every action is audited in the same log. Using IAM Identity Center would mean a second identity system and a second audit trail. |
| **Separate function** | Keeps the ops IAM permissions (CloudWatch, Cost Explorer, SQS redrive) away from the public API Lambda's role, the same reasoning the API already applies to mcp and stripe-webhook. |
| **Cheap** | Lambda plus API Gateway at admin traffic is roughly free. `GetMetricData` is about $0.01 per 1k metrics. Logs Insights is $0.005 per GB scanned, under 1 GB/month at Tier 0 with 30-day retention and a scan cap. Cost Explorer is $0.01 per call, cached, so under $1/month. **Estimate: $1–3/month total.** |
| **Efficient** | Same region (`us-east-1`), same API Gateway, so there's no extra hop or CORS. The ops Lambda batches several metrics into one `GetMetricData`. The client polls one `/ops/overview` endpoint every 30 s instead of 10 small ones. |

**Avoid:** a separate dashboard backend, Amazon Managed Grafana (about $9 per editor per month), OpenSearch (a $40+/month floor), per-key custom CloudWatch metrics (about $0.30 per metric per month, which multiplies by keys × routes), X-Ray on by default, and a VPC or NAT.

---

## 7. App architecture (`SubstratalKit` modules)

```
SubstratalKit/
├── APIClient/        generated (swift-openapi-generator) + middleware: Auth, Retry(429/503 Retry-After), Idempotency, ETag, Errors
├── Session/          actor SessionStore (single-flight refresh), Keychain, LockController (Touch ID, idle)
├── Capabilities/     computes can* flags + feature flags; refresh on 403 / foreground   (→ /users/me/capabilities when Plan 2 §7 lands)
├── Domain/           Directory, Access, Roles, Applications, Keys, Webhooks, Tenants, Orgs, Billing, Audit, Notifications, Push
├── Ops/              Overview, Metrics, Usage, Logs, Alarms, Jobs, Queues, Config, Integrations, Cost, Releases  (all behind `operations` flag)
├── Cache/            SwiftData models + TTL policy
├── Theme/            SubstratalTheme.swift (from specs repo) + chart palette roles
└── Telemetry/        spec §12 events (no PII) + ops screen_view ids
App (macOS target)/
├── Scenes/           Main WindowGroup, Route window, Sign-in Window, Settings, MenuBarExtra
├── Navigation/       Route enum (spec routes + /ops/*), deep links (substratal://, Universal Links)
├── Screens/          one folder per domain; views + @Observable view models
└── Components/       StatusBadge, AccessSwitch, SecretRevealSheet, StepUpConfirm, MetricTile, TimeRangePicker, LogTable
```

---

## 8. Build phases

Each phase ends with a notarized build in the Sparkle **beta** channel.

| Phase | Scope | API dependency | Rough size |
|---|---|---|---|
| **A. Foundation** | Xcode project, `SubstratalKit`, generated client, SessionStore, Keychain, Touch ID lock, sign-in + TOTP, Capabilities, sidebar with gating, themes, Route/deep links, error/empty/offline states, CI + notarization + Sparkle on S3 | none | 2–3 wks |
| **B. Administration (spec MVP)** | USR-*, ACX-*, ROL-*, AUD-*, GLB-* | none | 3–4 wks |
| **C. Developer** | APL-01..07, KEY-01..04 + hygiene panel, WHK-01..04, BIL-04 tenants | none | 3 wks |
| **D. Ops v1** | OPS-01 (✅ tiles), API key hygiene, cross-webhook failures (looped), alerts-as-notifications once Plan 2 §5 lands | Plan 2 §§2, 3, 5 (minimum) | 2–3 wks after the API side |
| **E. Ops v2** | OPS-02 Usage, OPS-03 Performance, OPS-04 Logs, OPS-06 Jobs & Queues, KEY-05 usage tab | Plan 2 §§2, 3 | 3 wks |
| **F. Control** | OPS-07 Configuration, OPS-08 Integrations, OPS-09 Cost, OPS-10 Releases, APL-08 Retire, step-up everywhere, MFA enforcement | Plan 2 §§1, 4, 6, 8 | 3 wks |
| **G. Personal Hub** | Home, Inbox, Account, Settings, Orgs, Plan & Billing, push devices (completes the spec's 75 screens) | none | 4–5 wks |

Phases B and C can start the day Phase A lands. Phases D–F are paced by Plan 2, which runs **in parallel** in the API repo. Phase G can move earlier if end users need the Hub sooner.

---

## 9. Acceptance criteria (Console-specific, in addition to the spec's per-screen DoD)

- [ ] Persona matrix: superadmin, operator, support, billing admin, app owner, plain member. The sidebar and every action button match §2 and the IA visibility rules, and a plain member sees no Operations, Administration or Developer section.
- [ ] No API key or AWS credential is ever stored by the app. A secret appears only in KEY-03, is excluded from screen capture, and the clipboard is cleared after 60 s.
- [ ] Every destructive admin action requires confirmation, plus step-up once available, and produces an audit event with `actor_type: user`.
- [ ] Overview first paint is under 500 ms from cache and under 1.5 s fresh on a warm Lambda. Polling stops when no window is visible.
- [ ] Every ops screen degrades cleanly to "Not available yet" on `404`/`501`.
- [ ] Notarized DMG plus Sparkle update verified from `downloads.substratalapps.com`. CI is green on `macos-15`.
- [ ] Ops alarm push arrives on a superadmin's Mac within 60 s of the alarm state change (once Plan 2 §5 lands).

---

## 10. Decisions to confirm

1. **One app (Hub, admin-first) vs. a separate Console.** I recommend one app (§1).
2. **Developer ID only for v1.** I recommend skipping the Mac App Store for the management build.
3. **Ops data through a new `ops` Lambda in the API**, not AWS SDK calls from the app. I recommend this (§6.2).
4. **Spec housekeeping:** OPEN-QUESTIONS #16 in the specs repo says notifications return `501`. The API's `plan-remaining.md` (2026-10-20) says push notifications are built, so the specs repo should be updated, along with the new OPS screens (§5.3).
