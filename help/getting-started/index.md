---
layout: default
title: Getting Started
nav_order: 2
permalink: /getting-started/
---

# Getting Started
{: .no_toc }

Install Substratal Hub, sign in, and find your way around.
{: .fs-6 .fw-300 }

1. TOC
{: toc }

---

## What you need

- A Mac running **macOS 15 Sequoia or later**.
- A Substratal account. Staff accounts are created by a superadmin, which sends you an invitation email. Developers can sign up from the web Hub.
- **Two-factor authentication**, if your account administers anything. Turn it on under **Account → Security** after you first sign in.

## Install

Download the latest build from the [Releases page](https://github.com/CompositeCode/substratalapps-macos/releases), open the disk image, and drag **Substratal Hub** to Applications. Builds are signed and notarized by Apple. Once installed, the app updates itself.

{: .note }
Until the first notarized release is published, the app is built from source: see the repository's README.

## Sign in

1. Open Substratal Hub. The sign-in screen ([AUTH-01](../screens/auth-01/)) appears.
2. Enter your email and password, and choose **Sign In**.
3. If your account has two-factor authentication on, enter the 6-digit code from your authenticator app ([AUTH-02](../screens/auth-02/)). Lost your phone? Choose **Use a recovery code** and enter one of the codes you saved when you turned two-factor on.

You stay signed in until you sign out, until 30 days pass without using the app, or for at most 90 days, whichever comes first. The app keeps your session in the macOS Keychain, on this Mac only. Signing out ends the session on the server too.

## Find your way around

The window has a **sidebar** on the left and the selected screen on the right.

| Section | What's in it | Who sees it |
|---|---|---|
| **Personal** | Home (your apps), Inbox, Organizations, Account, Plan & Billing, Settings | Everyone |
| **Administration** | Users, Access, Roles, Audit Log, Send notification | Staff with the matching permission, and app owners (Access only) |
| **Developer** | Applications, API Keys, Webhooks, Tenant | App owners, and staff who manage them |

You only see what your account can use. If a section or item is missing, your account doesn't have the permission it needs. See [Roles and permissions](../concepts/roles-and-permissions/).

Every screen shows its ID (for example `USR-01`) under the title. Use **Help → Help for This Screen** (or the **?** button in the toolbar) to open its page here.

{: .macos }
Press **⌘1** to **⌘6** for the Personal items, **⌥⌘1** to **⌥⌘4** for Administration and **⌃⌘1** to **⌃⌘4** for Developer. Right-click any sidebar item and choose **Open in New Window** to keep it alongside another screen. See [Keyboard Shortcuts](../reference/keyboard-shortcuts/).

## Choose which API the app talks to

Most people never change this. Developers working on the platform itself can point the app at a local copy of the API:

1. Choose **Substratal Hub → Settings…** (⌘,) and open **Connection**.
2. Choose **Local devserver** and check the URL (`http://localhost:8080` by default, the API repository's `make run`).

Switching signs you out. Production and the devserver each keep their own session, so a production token is never sent to a local server.

## Next

- [Tutorials](../tutorials/) for common jobs, step by step.
- [Concepts](../concepts/) to understand access, roles and Applications.
