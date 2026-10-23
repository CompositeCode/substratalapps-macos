---
layout: default
title: FAQ
nav_order: 7
permalink: /faq/
---

# Frequently Asked Questions
{: .no_toc }

1. TOC
{: toc }

---

## Using the Hub

### Why can't I see Administration or Developer in the sidebar?
{: #why-cant-i-see-administration }

The sidebar only shows what your account can use. Administration needs a staff permission (such as `users.list` or `audit.view`) or owning an app; Developer needs owning an app or a developer permission. See [Roles and permissions](../concepts/roles-and-permissions/).

### Does turning an app off delete anything?

No. It flips one switch. Roles, profile and settings in the app are kept and come back when you turn it on again. See [How access works](../concepts/how-access-works/).

### Someone still has access after I turned it off. Why?

They probably have another path to the app, such as a Standard subscription or an organization's seats. Choose **Why?** on their Access tab to see every path.

### Can I undo a change?

Turning access on or off can be undone with **⌘Z** for 10 seconds. Other changes can't be undone, but every one is in the [Audit Log](../tutorials/investigate-with-the-audit-log/) with the before and after values.

### Where is the Operations console (health, traffic, logs, alarms, cost)?

In the web Hub only. It reads AWS monitoring data through a server the native apps can't reach without exposing that data publicly. The macOS app has everything else.

### Can I use the Hub on more than one Mac?

Yes. Sign in on each. Each Mac has its own session, listed under **Account → Security**, where you can end any of them.

### Is my password stored on this Mac?

No. The app stores only a session token, in the macOS Keychain, readable only by this app on this Mac. Signing out deletes it.

## API keys

### I lost an API key's secret. Can I see it again?

No, secrets are shown once. Open the key and choose **Rotate** to issue a new secret; the old one stops working immediately.

### Should I use an API key in a website or app that runs in the browser?

No. The API refuses API keys sent from a browser (`400 api_key_in_browser`). Keys belong on servers. Browser apps sign people in instead.

### What does "Block destructive operations" do?

A key with it on can't turn access off, revoke, delete or suspend anything, whatever permissions it has. Keys for AI agents have it on by default.

## API versions

### Why don't the API's URLs have `/v1` in them anymore?

The API version moved into a header: every request sends `Substratal-Version: 1`, and URLs stay the same across versions. Old `/v1/…` URLs return `404`. See [API versioning](../api/versioning/).

### How do I know which API version this app uses?

**Settings → Connection** shows it, and so does the [Platform API](../api/) page for each version of this Help Center.

### Will the app stop working when the API changes?

Not without warning. Additive changes don't affect it. A breaking change ships as a new API version, and the old one keeps working for at least 6 months. The app shows **Update available** with the date it will stop working.
