# Plan 2 — What the API is missing for a management app

**Status:** proposal, 2026-10-21. Belongs in the API repo (`CompositeCode/substratalapps.com`) once agreed: spec first, then `make gen`, then code, following that repo's "Rules for every change".
**Companion:** [PLAN-management-app.md](PLAN-management-app.md). Section numbers here (§1–§9) are the ones Plan 1 cites.

> ### Update, 2026-10-23: tracked as issues now
>
> This plan became the `[api-gaps]` issues in the API repo, which are now the source of truth: [issues G1–G21](https://github.com/CompositeCode/substratalapps.com/issues?q=is%3Aissue+%22%5Bapi-gaps%5D%22). Paths below have been updated for **header versioning**: no `/v1` prefix; send `Substratal-Version: 1`.
>
> | This plan | Issue | State on 2026-10-23 |
> |---|---|---|
> | §9 `ops.*` permissions | G10 [#47](https://github.com/CompositeCode/substratalapps.com/issues/47) `operations.view` / `operations.manage` | Open |
> | §1 platform config and flags | G11 [#48](https://github.com/CompositeCode/substratalapps.com/issues/48), G12 [#49](https://github.com/CompositeCode/substratalapps.com/issues/49) per-key limits | Open |
> | §2 request log line, usage rollups | G6 [#43](https://github.com/CompositeCode/substratalapps.com/issues/43), G7 [#44](https://github.com/CompositeCode/substratalapps.com/issues/44) | Open |
> | §3 ops read endpoints | Moved to the **web Hub's Ops gateway** (specs PRODUCT-SPEC §2a); job runs G9 [#46](https://github.com/CompositeCode/substratalapps.com/issues/46), delivery health G8 [#45](https://github.com/CompositeCode/substratalapps.com/issues/45) | Open |
> | §4 MFA for staff, step-up | G13 [#50](https://github.com/CompositeCode/substratalapps.com/issues/50); passkeys G21 [#65](https://github.com/CompositeCode/substratalapps.com/issues/65) | Open |
> | §4 revoke all of a user's sessions | G14 [#51](https://github.com/CompositeCode/substratalapps.com/issues/51): `POST /users/{id}/sessions/revoke-all` | **Shipped** |
> | §6 retire / delete Applications | G15 [#52](https://github.com/CompositeCode/substratalapps.com/issues/52) | Open |
> | §7.2 users by role | G17 [#54](https://github.com/CompositeCode/substratalapps.com/issues/54): `GET /users?role_id=` | **Shipped** |
> | §7.3 bulk operations | G18 [#55](https://github.com/CompositeCode/substratalapps.com/issues/55) | Deferred until demand |
> | §7.4 audit export | G19 [#56](https://github.com/CompositeCode/substratalapps.com/issues/56): `POST /audit-exports` | **Shipped** |
> | §7.7 test-user expiry | [#30](https://github.com/CompositeCode/substratalapps.com/issues/30) | **Shipped** |
> | Not in this plan | G1 CORS [#38](https://github.com/CompositeCode/substratalapps.com/issues/38) (shipped), G2 go-live [#39](https://github.com/CompositeCode/substratalapps.com/issues/39), G3 spec update [#40](https://github.com/CompositeCode/substratalapps.com/issues/40), G4 staff read limits [#41](https://github.com/CompositeCode/substratalapps.com/issues/41), G5 client IP via BFF [#42](https://github.com/CompositeCode/substratalapps.com/issues/42), G16 exact counts [#53](https://github.com/CompositeCode/substratalapps.com/issues/53), G20 subscriber list [#57](https://github.com/CompositeCode/substratalapps.com/issues/57) | |

---

## 0. Assessment

**The API is ready for the object-management half of the Console.** All 118 operations in `openapi.yaml` (1.0.0-draft.3) are implemented, production answers `GET /health`, and the permission model (13 platform permissions, seed roles, escalation guards, `restrict_destructive`, ETags, idempotency, audit hot window) is solid admin-tool material.

**The system-management half isn't there.** The API manages *tenants' data* but exposes nothing about *itself*:

| Area | Today | Where it actually lives |
|---|---|---|
| Health | `GET /health` → `{"status":"ok"}` (shallow) | — |
| Metrics | none | CloudWatch built-in metrics (API GW, Lambda, Aurora, SQS) plus 3 security metric filters |
| Usage per key/app | `api_keys.last_used_at` only | `rate_limit_counters` (per principal per minute, purged after 2 days). The API Gateway access log has **no principal, key, app or route template**. |
| Logs | none | CloudWatch Logs, 30-day retention |
| Alarms | none | 7+ CloudWatch alarms → SNS → one email address |
| Configuration | none | env vars, Terraform vars, Go constants (`ratelimit.go`) |
| Feature flags | none (the client spec assumes "remote config") | — |
| Jobs / queues | none | EventBridge Scheduler, SQS + DLQ |
| Cost | none | Budgets, Cost Anomaly Detection |
| Release info | none | GitHub Actions, the S3 artifact bucket, `schema_migrations` |

Plus a handful of gaps in the existing resource API (§6–§7) and admin security (§4).

**Priority order** (what unblocks the most Console screens per unit of work):
**P0:** §2 usage logging, §3 ops read endpoints, §4 MFA for admins, §9 the `ops.*` permissions.
**P1:** §5 alerts into notifications, §6 application retirement, §7 small resource gaps.
**P2:** §1 configuration & flags, §8 ops actions, the rest.

---

## §9 (first, because everything depends on it): new platform permissions

| Key | Grants | Seed roles |
|---|---|---|
| `ops.view` | Read every `/ops/*` endpoint, receive ops alerts | superadmin, **new seed role `operator`** |
| `ops.manage` | Ops writes: run jobs, redrive DLQ, ack/mute alarms, edit alert rules, edit platform config, maintenance mode | superadmin, operator |

These are expand-only: the catalog enum, the seed-role migration and the docs page "Platform permission catalog". `operator` = `ops.view`, `ops.manage`, `audit.view`, `users.list`. The superadmin seed role gains both. Neither is app-confinable, so API keys can hold `ops.view` (useful for an external status page) but `ops.manage` requires a User token.

---

## §1. Platform configuration and feature flags

**Gap:** nothing an operator might want to change at runtime can be changed without a deploy. The client spec's feature flags have no server source.

**Add:**
- Table `platform_settings (key text pk, value jsonb, version int, updated_by, updated_at)` plus `platform_settings_history`, with RLS bypass for platform scope only.
- `GET /platform/config`. Returns everything with an `ETag`. `ops.view` sees all of it; any authenticated caller gets the public subset (flags and maintenance).
- `PATCH /platform/config` (`ops.manage`, `If-Match` required, writes `platform.config_updated` with before/after). Each key has a JSON-Schema-validated value.
- `GET /platform/config/history?key=`.
- Initial keys:
  - `flags.*` — the client spec's list: `organizations`, `notifications`, `push`, `billing`, `sso`, `passkeys`, `webhooks`, `app_registration_self_service`, `audit_export`, …
  - `rate_limits.default_per_principal`, `rate_limits.overrides[{op, limit}]`, `rate_limits.per_key_overrides[{key_id, limit}]`. These are read on each request through a 60-second in-Lambda cache, so there's no DB hit per request.
  - `signup.mode` (`open` / `invite_only` / `closed`), `signup.allowed_domains`
  - `security.require_mfa_for_platform_roles`, `security.admin_session_idle_minutes`, `security.admin_ip_allowlist` (CIDRs)
  - `maintenance.mode` (`off` / `read_only` / `full`), `maintenance.message`. When it's on, writes return `503 service_unavailable` with `Retry-After`. `ops.manage` holders bypass it, and `/health` and `/ops/*` stay up.
- Settings that **stay** in Terraform/env (shown read-only in the Console via `/ops/runtime`): region, CORS origins, email sender, push backend, KMS key ids, API Gateway stage throttle.

## §2. Usage data (per key / app / route / user)

**Gap:** no way to answer "who is calling, how much, with what errors". The access log format is `{requestId, ip, method, path, status, latency, integration}`, with no principal and no route template, and nothing aggregates.

**Add (cheap path, no new AWS services):**
1. **One structured log line per request** from the api Lambda (`internal/core/call.go`, after the response): `{"msg":"request","request_id","op","route","status","latency_ms","principal_type":"user|api_key|anon","principal_id","api_key_id","application_id","tenant_id","test_mode","rate_limited":bool,"error_code"}`. Never log tokens, emails or bodies. This also enables §3 logs search.
2. **Extend the API Gateway access log** with `$context.routeKey`, `$context.integrationLatency`, `$context.identity.userAgent` and `$context.error.message`. It's a Terraform-only change.
3. **Hourly rollup job** `usage-rollup` (in the existing `jobs` Lambda and EventBridge schedule). It runs a Logs Insights query over the last closed hour and upserts into `usage_hourly (hour, application_id, api_key_id, op, status_class, test_mode, requests, errors_4xx, errors_5xx, rate_limited, p50_ms, p95_ms, p99_ms)`. Retention is 400 days, then delete, and a daily rollup stays forever. The cost is a few cents a month at Tier 0 volume.
4. **Endpoints:**
   - `GET /usage?from&to&granularity=hour|day&group_by=application|api_key|op|status_class&application_id&api_key_id&test_mode`
     - Platform scope needs `ops.view`.
     - **App owners and app-scoped keys can read their own app's usage.** That gives developers visibility too.
   - `GET /api-keys/{id}/usage`: a convenience, same shape.
5. **Docs:** a new "Usage" API reference page. NFR notes that usage is accurate to the hour, and the last hour comes from §3 live metrics.

## §3. Ops read endpoints (new `ops` Lambda)

**Gap:** health, metrics, logs, alarms, queues, jobs, cost and release info are only visible in the AWS console.

**Add** `cmd/ops` as a new Lambda behind the existing API Gateway at `/ops/*`. It reuses `internal/core`'s auth pipeline (so `401`/`403`, rate limits and audit behave the same) and has **its own IAM role** with read-only CloudWatch, Logs, SQS, Scheduler, Cost Explorer and Lambda `GetFunction` access. All endpoints need `ops.view`.

| Endpoint | Returns | Source |
|---|---|---|
| `GET /ops/overview` | One call for the dashboard: status, the last hour's request/error/429 totals and p95, open alarms, queue depths, ACU, MTD cost, pending reviews and tier changes | aggregates the rows below, cached 30 s in-Lambda |
| `GET /ops/health` | Per component `{name, status: healthy\|degraded\|down\|unknown, checked_at, detail}` for Aurora (`select 1` via Data API), KMS (`DescribeKey`), SQS, SES (send quota, sandbox flag), Stripe (last webhook received at), APNs/FCM/Web Push (last success/failure per provider), the jobs (last run) | live checks, cached 30 s |
| `GET /ops/metrics?set=traffic\|latency\|lambda\|db\|queues\|security&from&to&period` | Time series | one `GetMetricData` per call |
| `GET /ops/logs?query=&filters…&from&to&limit` | Structured log rows (request + security + app logs) | Logs Insights with a server-built query (no raw query strings from clients), max 24 h range and a scan cap; results paged by cursor |
| `GET /ops/alarms` · `GET /ops/alarms/{name}/history` | Alarm state, reason, threshold, history | `DescribeAlarms`, `DescribeAlarmHistory` |
| `GET /ops/queues` | Webhook/push queue depth, oldest age, DLQ count, outbox pending/failed counts | SQS attrs + outbox tables |
| `GET /ops/jobs` | Each scheduled job: schedule, last run start/end/result/error, next run | new `job_runs` table written by `cmd/jobs`, plus `Scheduler GetSchedule` |
| `GET /ops/deliveries?status=failed&since=` | Webhook deliveries failing across **all** webhooks (today only per webhook) | outbox tables |
| `GET /ops/push-stats?application_id&from&to` | Push sent / failed / invalid-token per provider per app | push outbox |
| `GET /ops/cost` | MTD and forecast vs. warn/hard budgets, top services | Cost Explorer + Budgets, **cached 6 h in Postgres** (CE costs $0.01 per call) |
| `GET /ops/releases` | Deployed commit SHA, deploy time, function versions/aliases, latest migration, docs version, previous release | Lambda env (`GIT_SHA`, `DEPLOYED_AT` set by `deploy.yml`) + `schema_migrations` |
| `GET /ops/runtime` | Read-only non-secret runtime config (region, CORS origins, email sender, push backend, throttle) | env |

The `/health` contract stays as is (it's the smoke test's dependency).

## §4. Admin security

**Gaps:**
1. **MFA isn't enforceable.** TOTP is optional and self-service for every user, including superadmins.
2. **No step-up re-authentication** for destructive admin operations. A stolen 15-minute access token can suspend users, revoke keys or rotate push credentials.
3. **No admin network restriction.**
4. **Audit covers writes but not sensitive operations that aren't writes.** The `AuditAction` enum has no event for a data export (`GET /users/{id}/export`), an admin revoking someone's session, staff sending a notification, or an admin login. Logins appear only as `security` log lines.
5. **No "sign out everyone" incident control**, and no single call to revoke all of one user's sessions.

**Add:**
- Setting `security.require_mfa_for_platform_roles` (§1), default **on**. A user holding any platform permission without TOTP gets `403 mfa_required` on every endpoint that needs a platform permission. Self-service account endpoints still work, so they can enroll.
- **Step-up:** `POST /auth/step-up {code}` → a short-lived (5 min) `step_up` claim on a fresh access token. Destructive platform operations, already classified for `restrict_destructive`, require it for User callers when the caller is acting on someone else: `403 step_up_required`. The Console shows the TOTP sheet and retries.
- `security.admin_ip_allowlist` applies to platform-permission use only, never to end users.
- New audit actions: `user.data_exported`, `session.revoked` (admin-initiated, with target), `notification.sent` (staff), `auth.admin_login` (sign-in by a platform-permission holder), `platform.config_updated`, `ops.job_run`, `ops.dlq_redriven`, `ops.alarm_muted`, `application.retired`. Add `target_type` values for `platform` and `job`.
- `DELETE /users/{id}/sessions` (revoke all; `users.manage`), and `POST /ops/sessions/revoke-all {scope: all|platform_roles|test_mode}` (`ops.manage` + step-up) for incident response.

## §5. Alerts and notifications to admins

**Gap:** alarms only email a single `alarm_email` from SNS. The API already has a full inbox-and-push system with platform notifications to `app_hub`, but ops doesn't use it.

**Add:**
- Subscribe the `ops` Lambda to the existing SNS alarm topic. On each state change:
  - Write a **platform notification** (`category: ops.alarm`, severity, deep link `substratal://ops/alerts/{name}`) to every user holding `ops.view`. Push goes through the existing APNs/FCM path, so Macs and iPhones get Time Sensitive alerts.
  - Emit a webhook event `ops.alarm.state_changed` to **platform-scoped** webhooks.
- Other new webhook events: `ops.config_changed`, `ops.release_deployed`, `ops.job_failed`. With these, Slack or PagerDuty bridges are just webhook receivers. Optionally add built-in senders configured through `PUT /ops/alert-routes` (`ops.manage`), with Slack and PagerDuty secrets KMS-encrypted like webhook secrets.
- Missing alarms (Terraform):
  - p95 latency on hot paths vs. the 150 ms NFR
  - `429` rate spike
  - push failure rate per provider
  - outbox age (oldest pending delivery older than 10 min)
  - job failure (from `job_runs`)
  - SES bounce/complaint rate
  - a budget-threshold alarm into the same topic (today Budgets emails separately)
- `PATCH /ops/alarms/{name}` for thresholds on a whitelisted set of user-tunable alarms only (`PutMetricAlarm` with constraints). Terraform marks those thresholds `ignore_changes`, so a deploy doesn't fight the Console. Also `POST /ops/alarms/{name}/mute {until}`.

## §6. Application lifecycle: removal

**Gap:** `/applications/{id}` supports only `GET` and `PATCH`. An application can be suspended through `review_status` but **never retired or removed**, which the brief requires ("from adding to removing applications").

**Add:**
- `POST /applications/{id}/retire` (`applications.manage` + step-up): `review_status → retired` (a new terminal value). In one transaction it:
  - disables all entitlements (`access.revoked` reason `application_retired`)
  - revokes the app's API keys
  - deactivates its webhooks and push credentials and devices
  - writes `application.retired`
  - It keeps the rows for audit. Retired apps leave the catalog.
- `DELETE /applications/{id}`: hard delete, only when the app was never approved or has had zero entitlements ever (for example, a mistaken registration). Otherwise `409 application_in_use`, so retire it instead.
- Tenant follow-up: a Tenant whose last Application retires moves to `status: inactive`.
- Docs: the "Applications → The review lifecycle" state diagram gains `retired`.

## §7. Small gaps in existing resources

| # | Gap | Add | Used by |
|---|---|---|---|
| 7.1 | Capabilities take 6 calls (spec CLIENT-ARCHITECTURE §5) | `GET /users/me/capabilities` → platform permissions (union), owned apps/tenants, org-admin orgs, plan, **feature flags (§1)**, `mfa_required`, `step_up_valid_until` | every screen; cuts launch latency |
| 7.2 | No role-holder lookup (spec OQ #5) | `GET /users?role_id=` | ROL-02 |
| 7.3 | No bulk endpoints (spec OQ #6) | `POST /batch` accepting up to 50 sub-requests of an allowlisted set (entitlement toggle, role assign/remove, suspend), each with its own idempotency key and per-item result; one transaction per item | USR-01, ACX-05 |
| 7.4 | Audit search and export | `q` (free text over action/target/actor display names), `GET /audit-events/stats?group_by=action\|actor&period=day`, and the Phase 3 export pulled forward: `POST /audit-exports` → S3 presigned URL (JSONL), `audit.view` + step-up | AUD-01, compliance |
| 7.5 | Webhook deliveries only per webhook | covered by `/ops/deliveries` (§3) | OPS-06 |
| 7.6 | Avatar/icon upload (spec OQ #1) | `POST /uploads` → presigned S3 PUT on the existing static-assets bucket + CloudFront URL | APL-02 icon, ACC-01 |
| 7.7 | Test-mode User expiry | already specified, not built (`plan-remaining.md`). The Console's test-user tooling depends on it. | USR-02 |
| 7.8 | API key per-key rate-limit visibility | include `rate_limit: {limit, remaining_now}` on `GET /api-keys/{id}` (read from `rate_limit_counters` via the existing `peek`) | KEY-04 |
| 7.9 | Application owner transfer | `PATCH owner_user_id / owner_organization_id` (`applications.manage`, writes an audit event), if not already allowed. Verify against the current PATCH allowlist. | APL-03 |

## §8. Ops actions (`ops.manage`, User token + step-up)

| Endpoint | Does |
|---|---|
| `POST /ops/jobs/{name}/runs` | Invoke the jobs Lambda for that job now. Records `job_runs` plus `ops.job_run`. |
| `POST /ops/queues/{name}/redrive` | SQS `StartMessageMoveTask` from the DLQ back to the source queue |
| `POST /webhooks/deliveries/redeliver` `{ids[]}` | Bulk redeliver (the per-delivery endpoint exists today) |
| `PATCH /platform/config` (maintenance, rate limits, flags) | see §1 |
| `POST /ops/sessions/revoke-all` | see §4 |
| *(Phase 3)* `POST /api-keys/{id}/deliver` `{secret_arn}` | Rotate and write the new secret straight into a named Secrets Manager secret the ops role may write (tagged `substratal:managed-key=true`). Keeps internal-key secrets off clipboards. |

**Deliberately not added:** triggering deploys or rollbacks from the Console. Releases stay in GitHub (`deploy.yml` / `rollback.yml`) where the OIDC trust and the `production` environment gate live. The Console shows release info (§3) and links to the workflow.

---

## Cost of all of the above (Tier 0)

| Item | Monthly |
|---|---|
| `ops` Lambda + API GW calls at admin volume | ≈ $0 (free tier) |
| Extra structured log line per request (≈ 300 bytes) | ≈ $0.15 per 1M requests ingested |
| Hourly Logs Insights rollup (≈ 720 queries, small scans) | < $0.50 |
| `GetMetricData` from dashboards | < $0.50 |
| Cost Explorer (cached 6 h) | ≈ $1.20 |
| New alarms (≈ 8 standard) | ≈ $0.80 |
| Postgres tables (`usage_hourly`, `platform_settings`, `job_runs`) | within the existing Aurora floor |
| **Total added** | **≈ $2–4 / month** |

There are no new always-on services: no OpenSearch, no Grafana, no Redis, no VPC or NAT.

---

## Suggested API-repo sequencing

| Release | Contents | Unblocks Console phase |
|---|---|---|
| R1 | §9 permissions + `operator` role · §2.1–2.2 request logging · §3 `ops` Lambda with `overview`, `health`, `metrics`, `alarms`, `queues`, `releases` · §7.1 capabilities · §7.2 role filter | D (Ops v1) |
| R2 | §2.3–2.4 usage rollup + `/usage` · §3 `logs`, `jobs` (+ `job_runs`), `deliveries`, `push-stats`, `cost` · §5 alarms → notifications + webhook events | E (Ops v2) |
| R3 | §4 MFA enforcement, step-up, new audit actions, revoke-all · §6 retire/delete application · §7.3 batch · §7.4 audit search/export | F (Control) |
| R4 | §1 platform config + flags + maintenance · §5 alert routes and tunable alarms · §8 ops actions | F (Control) |

Each release follows the API repo's rules: spec and docs page first, `make gen`, contract tests, expand-only migrations, and a changelog entry.

---

## Housekeeping found during review

- **Specs repo, OPEN-QUESTIONS #16** says every Notifications operation returns `501`. The API's `plan-remaining.md` (2026-10-20) says push notifications and the inbox are implemented. Update #16 and the `notifications`/`push` flag defaults.
- **API repo README** still lists `docs/roadmap.md` and `docs/domain-model/database-schema.md` as "should move to root". That doesn't block anything here.
- **First-party pages missing** (`plan-remaining.md`): dashboard `verify-email` / `reset-password` and hosted sign-in. Not needed by the Console, which uses the embedded login, but needed before email-based admin invitations work end to end, because AUTH-07 links land on the web dashboard.
