---
layout: default
title: Versioning
parent: Platform API
nav_order: 2
permalink: /api/versioning/
---

# Versioning
{: .no_toc }

How the Platform API is versioned, which version each Hub release uses, and how changes and deprecations reach you.
{: .fs-6 .fw-300 }

1. TOC
{: toc }

---

## The version is a header

Every request names the API version it was written for:

```
GET https://api.substratalapps.com/users/me
Authorization: Bearer …
Substratal-Version: 1
```

- **Required.** No header → `400 api_version_required`. An unknown value → `400 unsupported_api_version`. Both list the versions served in `details.supported`. There's no default, so the API never moves you to a new version without asking.
- **Not in the URL.** Paths are the same in every version. The old `/v1/…` paths return `404`.
- **Echoed.** Responses carry `Substratal-Version` with the version that served them.
- **Exempt:** `GET /health`, `POST /auth/oauth/token` (standard OAuth libraries can't add headers), `/.well-known/*`, and SCIM under `/scim/v2`. Sending the header to them is harmless.

Versions served today: **{{ site.data.build.api_header_versions | join: ", " | default: "1" }}**.

## What changes within a version, and what doesn't

| Change | Ships as | What you need to do |
|---|---|---|
| New endpoint, new optional field, new enum value | The same version | Nothing, if your client ignores unknown fields and handles unknown enum values. |
| Removing or renaming a field, changing a type or a meaning | The next version number | Move to it within the deprecation window. |

## Deprecation and sunset

When a version is deprecated, every response to a request that names it carries:

- `Deprecation` ([RFC 9745](https://www.rfc-editor.org/rfc/rfc9745)): it's deprecated, and since when.
- `Sunset` ([RFC 8594](https://www.rfc-editor.org/rfc/rfc8594)): the date it stops working, **at least 6 months** later.

After the sunset date, requests naming it get `400 unsupported_api_version`.

The Hub apps handle this for you: **Update available** with the date when they see `Deprecation`, and **Update required** (no API traffic) on `unsupported_api_version`. Do the same in your own clients: log the headers and alert on them.

## Two version numbers, two meanings

| Number | Example | What it is |
|---|---|---|
| `Substratal-Version` | `1` | The **contract**: what you send in the header. Changes only for breaking changes. |
| Spec version (`info.version`) | `{{ site.data.build.api_spec_version | default: "1.0.0-draft.9" }}` | The **document**: bumps with every change to `openapi.yaml`, additive ones included. |
| Webhook payload version | `2026-10-05` | The shape of webhook payloads for one subscription. Separate from both. |

## Which version this documentation covers

| | This version of the Help Center |
|---|---|
| Hub for macOS | {{ site.data.build.app_version | default: "local build" }} |
| `Substratal-Version` | {{ site.data.build.api_header_version | default: "1" }} |
| Spec version | {{ site.data.build.api_spec_version | default: "—" }} |
| Operations | {{ site.data.build.api_operations | default: "—" }} |

Every published version of this site is frozen under [Versions](../../versions/), with the API version it described, so a link from an older app or an older integration still shows what applied then. What changed in the API itself, version by version, is in the API's [Changelog](https://compositecode.github.io/substratalapps.com/changelog/).

## How this documentation stays current

The Help Center is rebuilt and published automatically:

- **When the app changes:** every merge to `main` that touches the app, its screen catalog, `CHANGELOG.md` or these pages publishes a new version.
- **When the API changes:** a scheduled job checks the API's `openapi.yaml` daily (and on request from the API repository). If it changed, it opens a pull request updating the app's generated client and this site together. CI must build the app against the new spec before it can merge, and merging publishes the docs.
