---
layout: default
title: Register an Application
parent: Tutorials
nav_order: 5
permalink: /tutorials/register-an-application/
screens: [APL-01, APL-02, APL-03, APL-06]
---

# Register an Application
{: .no_toc }

Add an app to the Substratal catalog so people can be given access to it.
{: .fs-6 .fw-300 }

{% include availability.html %}

**You'll need:** a verified email address. Staff with `applications.manage` can also register apps for others and review submissions.

1. Under **Developer**, choose **Applications** (⌃⌘1), then **Register App** (⇧⌘N).
2. Fill in its **Name**, **Slug** (used in permission keys like `app.timetrack.export`; can't change later), **Description** and **Launch URL**.
3. Choose **Register**.

Your app is created **pending review**. Until it's approved, only you and Substratal staff can see it, and nobody can be given access to it or launch it. You can still set it up: its permissions, roles, settings schema, API keys and webhooks.

## Review (staff)

Open **Applications** and filter by **Pending review**: that's the queue, oldest first.

- **Approve** puts it in the catalog.
- **Reject** needs a note saying what to fix. The developer edits the app and it returns to the queue.
- **Suspend** (with a note) stops new grants and new sign-ins to an approved app, for example if its signing secret looks compromised. Existing access is left as it is, and **Approve** reinstates it.

## Next steps for the app

- Define its permissions and roles (**Permissions & roles** tab).
- [Create an API key](../create-an-api-key/) for its backend.
- Add a webhook so it hears `access.revoked` immediately.
- Add push credentials if it sends notifications.
