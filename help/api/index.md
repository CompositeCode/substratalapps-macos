---
layout: default
title: Platform API
nav_order: 8
has_children: true
permalink: /api/
---

# Platform API
{: .no_toc }

The API every Hub app is built on, and that your Applications call too. This page is the quick guide; the [interactive reference](reference/) lists every endpoint, and the [API specification site](https://compositecode.github.io/substratalapps.com/) is the system of record.
{: .fs-6 .fw-300 }

1. TOC
{: toc }

---

## At a glance

| | |
|---|---|
| Base URL | `{{ site.data.build.api_base_url | default: "https://api.substratalapps.com" }}`, no version segment in the path |
| Version | `Substratal-Version: {{ site.data.build.api_header_version | default: "1" }}` request header, **required** on every request (see [Versioning](versioning/)) |
| Specification | OpenAPI 3.1, spec version `{{ site.data.build.api_spec_version | default: "—" }}`, {{ site.data.build.api_operations | default: "—" }} operations: [interactive reference](reference/) · [download openapi.yaml]({{ '/api/openapi.yaml' | relative_url }}) |
| Authentication | `Authorization: Bearer <token>`: a person's access token, or an API key |
| Format | JSON, UTF-8. Timestamps are ISO 8601 UTC with `Z`. IDs carry a type prefix (`usr_`, `app_`, `key_`, `req_`…). |

This is the API version this version of the Help Center (and of the macOS app) was built against. Older ones are under [Versions](../versions/).

## Your first request

```bash
curl https://api.substratalapps.com/health
# {"status":"ok"}    ← the only call that works without a version header or a token

curl https://api.substratalapps.com/users/me \
  -H "Authorization: Bearer $TOKEN" \
  -H "Substratal-Version: 1"
```

Without the header you get:

```json
{ "error": { "code": "api_version_required", "message": "This request requires a Substratal-Version header.", "details": { "supported": ["1"] } } }
```

{: .important }
Older examples used `https://api.substratalapps.com/v1/…`. Those paths now return `404 not_found`, with no redirect. Drop `/v1` and send the header instead.

## Authentication

| Credential | Looks like | Lives for | Use it for |
|---|---|---|---|
| **Access token** (a person) | JWT | 15 minutes | Apps acting for a signed-in person, like the Hub. Get one from `POST /auth/login` (plus `POST /auth/mfa/verify` if two-factor is on); renew it with `POST /auth/token/refresh`. |
| **Refresh token** | `rtk_…` | 30 days idle, 90 days at most; single use | Getting a new access token. Each refresh returns a new one; reusing an old one ends the session. |
| **API key** | `satk_live_…` / `satk_test_…` | Until revoked or its expiry | Servers, scripts and AI agents. Created in the Hub ([tutorial](../tutorials/create-an-api-key/)). Never from a browser. |
| **App token** | JWT, audience = your app | 5 minutes | What your Application receives when a person launches it; verify it against the JWKS. |

Signing in:

```bash
curl -X POST https://api.substratalapps.com/auth/login \
  -H "Substratal-Version: 1" -H "Content-Type: application/json" \
  -d '{"email":"dana@example.com","password":"…"}'
```

The response is either a session (`access_token`, `refresh_token`, `expires_in`) or, when two-factor is on, `{"mfa_required": true, "mfa_token": "…"}` to finish with `/auth/mfa/verify`.

## Conventions you'll meet

| Topic | In short |
|---|---|
| **Errors** | Always `{ "error": { "code", "message", "details" } }`. Branch on `code`, not `message`. |
| **Pagination** | `?limit=` (max 100) and `?cursor=`; responses carry `page.next_cursor` and `page.has_more`. |
| **Idempotency** | Send `Idempotency-Key: <uuid>` on creates. A retry with the same key returns the first result instead of creating twice. Some creates require it. |
| **Concurrency** | Reads return an `ETag`; send it back as `If-Match` on updates. If someone changed it first you get `409 version_conflict`. |
| **Rate limits** | 100 requests a minute per key or session by default, higher on hot paths. `RateLimit-*` headers show your budget; `429` comes with `Retry-After`. |
| **Request IDs** | Every response has `X-Request-Id: req_…`. Quote it when asking for help. |
| **Test mode** | Test keys and test users only ever see test data. |

Full details: [Conventions](https://compositecode.github.io/substratalapps.com/api-reference/conventions/).

## Examples

### Check whether a person can use your app

The call your backend makes on its hot path (300 requests a minute allowed):

```bash
curl https://api.substratalapps.com/users/usr_01JAG.../apps/app_timetrack/effective-permissions \
  -H "Authorization: Bearer $SUBSTRATAL_API_KEY" \
  -H "Substratal-Version: 1"
```

```json
{
  "user_id": "usr_01JAG...",
  "application_id": "app_timetrack",
  "allowed": true,
  "user_status": "active",
  "entitlement_status": "active",
  "access_paths": [{ "source": "purchase", "entitlement_id": "ent_01JAG...", "status": "active" }],
  "roles": ["role_timetrack_admin"],
  "effective_permissions": ["app.timetrack.export", "app.timetrack.manage_members"],
  "computed_at": "2026-10-05T12:00:00Z"
}
```

`allowed` is the one field most callers need. `effective_permissions` is always empty when it's `false`.

### Turn an app off for someone

```bash
curl -X PATCH https://api.substratalapps.com/entitlements/ent_01JAG... \
  -H "Authorization: Bearer $TOKEN" -H "Substratal-Version: 1" \
  -H "If-Match: W/\"7\"" -H "Content-Type: application/json" \
  -d '{"status":"disabled","disabled_reason":"Billing dispute"}'
```

### From Swift (as the Hub does)

The Hub generates its client from `openapi.yaml` with [swift-openapi-generator](https://github.com/apple/swift-openapi-generator) and adds the version header in one middleware, so no call can forget it:

```swift
struct VersionMiddleware: ClientMiddleware {
    func intercept(_ request: HTTPRequest, body: HTTPBody?, baseURL: URL, operationID: String,
                   next: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?))
        async throws -> (HTTPResponse, HTTPBody?) {
        var request = request
        request.headerFields[HTTPField.Name("Substratal-Version")!] = "1"
        return try await next(request, body, baseURL)
    }
}

let client = Client(serverURL: URL(string: "https://api.substratalapps.com")!,
                    transport: URLSessionTransport(),
                    middlewares: [VersionMiddleware(), AuthMiddleware(token: session.accessToken)])
let page = try await client.users_list(query: .init(limit: 50), headers: .init(substratalVersion: ._1))
```

See `Packages/SubstratalKit` in the [repository](https://github.com/CompositeCode/substratalapps-macos) for the complete version, with deprecation handling, token refresh and idempotency keys.

### Other languages

Generate a client from [`openapi.yaml`]({{ '/api/openapi.yaml' | relative_url }}): `openapi-typescript` + `openapi-fetch` (TypeScript), Kiota or NSwag (C#), `openapi-generator` (Kotlin, Python, Rust and others). Every operation has a stable `operationId`, and the version header is declared as the shared `ApiVersion` parameter, so generated clients know to send it.

## Webhooks

Your app should subscribe to at least `access.revoked` and `role.removed`, so it reacts to changes in the Hub immediately instead of polling. Deliveries are signed. A webhook's **payload version** (a date such as `2026-10-05`) is separate from `Substratal-Version`. See [Webhooks](https://compositecode.github.io/substratalapps.com/api-reference/webhooks/).

## AI agents

The platform runs an MCP server at `/mcp`. Give an agent its own API key with **Used by: Agent**, so destructive operations are blocked. See [MCP Server](https://compositecode.github.io/substratalapps.com/mcp-server/).
