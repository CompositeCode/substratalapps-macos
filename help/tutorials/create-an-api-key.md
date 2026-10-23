---
layout: default
title: Create an API key
parent: Tutorials
nav_order: 4
permalink: /tutorials/create-an-api-key/
screens: [KEY-01, KEY-02, KEY-03, KEY-04]
---

# Create an API key
{: .no_toc }

Give a backend service, script or AI agent its own credential for the Platform API.
{: .fs-6 .fw-300 }

{% include availability.html %}

**You'll need:** to own the app the key is for, or `api_keys.manage` for platform keys. An API key can never create another key: only a person can.

1. In the sidebar, under **Developer**, choose **API Keys** (⌃⌘2), then **Create Key** (⇧⌘N).
2. **Name** it after what will use it, such as `timetrack-backend`.
3. **Scope:** your app, or **Platform** (staff only).
4. **Mode:** **Live** for real users, **Test** for test-mode users only. You can't change this later.
5. **Used by:**
   - **Service:** code you wrote, calling fixed endpoints.
   - **Agent:** an AI agent or MCP client. This turns on **Block destructive operations**, so the key can't turn access off, delete or revoke anything, whatever its permissions.
6. Tick only the **Permissions** it needs.
7. Optionally set when it **Expires** (30, 90 or 365 days).
8. Choose **Create**.

## Save the secret: you see it once

The next screen shows the secret (`satk_live_…`). It is never shown again.

1. Choose **Copy** and paste it straight into where it's stored, such as your service's secret manager. The clipboard clears itself after 60 seconds.
2. Tick **I've saved this secret**, then choose **Done**.

{: .macos }
The secret window is hidden from screenshots and screen sharing while it's open.

Lost it? Open the key and choose **Rotate**. That issues a new secret and stops the old one working at once.

## Use the key

```bash
curl https://api.substratalapps.com/users/usr_01JAG.../apps/app_timetrack/effective-permissions \
  -H "Authorization: Bearer satk_live_..." \
  -H "Substratal-Version: 1"
```

Every request needs the `Substratal-Version` header. See [Platform API](../../api/).

## Keep keys tidy

On **API Keys**, the list shows each key's last 4 characters, when it was last used and when it expires. Revoke keys nobody uses (**⌘⌫**). Revoking is permanent.
