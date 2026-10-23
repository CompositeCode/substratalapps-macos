---
layout: default
title: Home
nav_order: 1
permalink: /
---

# Substratal Hub Help
{: .fs-9 }

Run the Substratal Apps platform: the people, their access to each app, roles and permissions, Applications, API keys, webhooks and the audit trail behind `{{ site.data.build.api_base_url | default: "https://api.substratalapps.com" }}`.
{: .fs-6 .fw-300 }

[Get started](getting-started/){: .btn .btn-primary .fs-5 .mb-4 .mb-md-0 .mr-2 } [Tutorials](tutorials/){: .btn .fs-5 .mb-4 .mb-md-0 .mr-2 } [API reference](api/){: .btn .fs-5 .mb-4 .mb-md-0 }

---

## What's here

| If you want to… | Go to |
|---|---|
| Install the app and sign in for the first time | [Getting Started](getting-started/) |
| Do a specific job, step by step (invite someone, turn an app off, create an API key) | [Tutorials](tutorials/) |
| Understand how access, roles and permissions fit together | [Concepts](concepts/) |
| Look up a screen you're on | [Screen Reference](screens/), or **Help → Help for This Screen** in the app |
| Find a keyboard shortcut | [Keyboard Shortcuts](reference/keyboard-shortcuts/) |
| Fix an error message | [Troubleshooting](reference/troubleshooting/) |
| Get a quick answer | [FAQ](faq/) |
| Build against the API the app uses | [Platform API](api/), with the [interactive reference](api/reference/) |
| See what changed | [Release Notes](release-notes/) and [Versions](versions/) |

## One Hub, several apps

Substratal Hub is one product with the same screens, names and routes on every platform: macOS (this app), the web Hub at `dashboard.substratalapps.com`, iOS, Android, Windows and Linux. This Help Center is written for all of them. Where a platform differs, the page says so:

{: .macos }
Keyboard shortcuts, menus, multiple windows and the Keychain are macOS-specific. The web Hub adds the Operations console (health, traffic, logs, alarms, cost), which the native apps leave out.

Each screen has an ID such as `USR-01`, shown under the window title. Every platform uses the same ID, and every ID has a page in the [Screen Reference](screens/), so a link from any Hub app lands on the right page.

## This version

| | |
|---|---|
| App version | {{ site.data.build.app_version | default: "local build" }} |
| Platform API | spec `{{ site.data.build.api_spec_version | default: "—" }}`, `Substratal-Version: {{ site.data.build.api_header_version | default: "1" }}`, {{ site.data.build.api_operations | default: "—" }} operations |
| Screens | {{ site.data.build.screens_built | default: "—" }} of {{ site.data.build.screens_total | default: "—" }} built |

Older versions of this site are kept under [Versions](versions/), so a link always shows what that version said.
