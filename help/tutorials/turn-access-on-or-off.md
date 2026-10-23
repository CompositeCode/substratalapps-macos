---
layout: default
title: Turn an app on or off for someone
parent: Tutorials
nav_order: 2
permalink: /tutorials/turn-access-on-or-off/
screens: [USR-03, ACX-01, ACX-02, ACX-03, ACX-04]
---

# Turn an app on or off for someone
{: .no_toc }

Give a person access to an app, or switch it off, without touching their data.
{: .fs-6 .fw-300 }

{% include availability.html %}

**You'll need:** `entitlements.manage`, or to own the app. App owners only see their own apps.

1. TOC
{: toc }

---

## Turn access off

1. Open **Users** (⌥⌘1) and select the person.
2. Choose the **Access** tab. Each app shows whether it's on for them, and why.
3. Flip the app's switch off. Add a **Reason** if you like; it's kept in the audit log.
4. Confirm **Turn off**.

Their sessions in that app end within minutes: apps are told immediately through the `access.revoked` webhook, and app tokens last at most 5 minutes.

{: .tip }
Changed your mind? Press **⌘Z** within 10 seconds to undo.

Turning access off keeps everything else: their roles, profile and settings in that app are untouched, and come back exactly as they were when you turn it on again. See [How access works](../concepts/how-access-works/).

## Give access

1. On the person's **Access** tab, choose **Grant access**.
2. Pick the **App** and the **Type**:
   - **Purchase:** they bought it outside Substratal. Add the **Order ID**.
   - **Trial:** set when it **Ends**.
   - **Admin grant:** you're giving it to them.
3. **Starts** defaults to now. Choose **Grant**.

You can't grant **Free** or **Standard** access by hand. The platform gives free apps to everyone, and Standard apps to subscribers, automatically. Those rows show "Managed by Substratal": you can turn them off and back on, but not edit or delete them.

## Find out why someone can or can't use an app

On the **Access** tab, choose **Why?** next to an app. It shows every path the person has to the app (their own grant, a Standard subscription, or an organization's seats) and which one decides the result. This is the same answer the app itself gets from the API.
