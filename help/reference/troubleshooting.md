---
layout: default
title: Troubleshooting
parent: Reference
nav_order: 2
permalink: /reference/troubleshooting/
---

# Troubleshooting
{: .no_toc }

What an error means and what to do about it.
{: .fs-6 .fw-300 }

1. TOC
{: toc }

---

## Signing in

| You see | Why | What to do |
|---|---|---|
| "That email and password don't match." | Wrong email or password. | Check both, or use **Forgot password?** |
| "Too many attempts." | Too many tries in a short time. | Wait a few minutes. |
| "This account is suspended." | An admin suspended the account. | Contact your Substratal admin. |
| "That code didn't work." | The two-factor code is wrong or expired (they change every 30 seconds). | Check your Mac's clock is set automatically, then try the current code. Or use a recovery code. |
| "This test account has expired." | Test-mode users stop working at their expiry time. | Create a new test user, or ask for the expiry to be extended. |
| You're asked to sign in again unexpectedly | Your session ended: you signed out elsewhere with **Sign out everywhere**, an admin ended it, 30 days passed without use, or 90 days passed since you signed in. | Sign in again. |

## Update notices

| You see | Why | What to do |
|---|---|---|
| **Update available.** This version stops working on a date. | The API is retiring the version this app was built for. You have at least 6 months. | Update the app (it updates itself, or download the latest release). |
| **Update required.** | The API no longer supports this version of the app. The app stops calling the API until it's updated. | Update the app. |

## Anywhere in the app

| You see | Code | What to do |
|---|---|---|
| A screen or button is missing | — | Your account doesn't have the permission. See [Roles and permissions](../../concepts/roles-and-permissions/). |
| "You don't have permission…" | `403` | Your permissions changed while you were working. The app refreshes them; ask an admin if you need more. |
| "Someone else changed this…" | `409 version_conflict` | Another person saved the same thing first. The app reloads it; make your change again. |
| "Too many requests." | `429` | The app slows down automatically. Wait a moment. |
| "Substratal is briefly unavailable." | `503` | Maintenance or an outage. The app retries; check again in a few minutes. |
| "Couldn't reach Substratal." | — | Check your network. If you use a VPN or proxy, check it allows `api.substratalapps.com`. |

## Reporting a problem

Choose **Help → Help for This Screen** to check you're on the right page, then report the screen ID (for example `USR-01`), what you did, and the time. Every API response carries a request ID (`req_…`) that support can look up. Please don't include passwords, tokens or API key secrets.

## For developers

API error codes, the error format and every status are in the API's [Conventions → Errors](https://compositecode.github.io/substratalapps.com/api-reference/conventions/#errors). The two version errors:

- `400 api_version_required`: the request had no `Substratal-Version` header. Always a client bug.
- `400 unsupported_api_version`: the header names a version the API doesn't serve. `details.supported` lists the ones it does.
